#!/usr/bin/env bash
# set-model.sh — xem/đổi model của từng role/agent OpenCode.
#
#   set-model.sh list                          liệt kê role -> model hiện tại
#   set-model.sh pick                          chọn model từng role (interactive; ghi kit-profile.env)
#   set-model.sh <role|agent> <provider/model[#variant]>   đổi 1 role/agent
#   set-model.sh --profile <tên|đường dẫn>     áp profiles/<tên>.env (role=model mỗi dòng)
#   set-model.sh --config-dir DIR ...          thao tác trên bản copy (mặc định ~/.config/opencode)
#
# Role và target (agents/*.md frontmatter hay key trong opencode.json) định nghĩa ở roles.conf.
# Agent lẻ không có trong roles.conf (vd title) vẫn set được bằng tên agent.
# Model không có trong provider của opencode.json vẫn được set, chỉ in cảnh báo.
# Env: KIT_MODEL_<ROLE> (vd KIT_MODEL_WORKER) ghi đè sẵn khi pick; KIT_FORCE_PROMPT=1 ép đọc stdin.
#
# Lưu ý worker-kit: scripts/dispatch.sh đọc model từ agents/worker.md,
# nhưng biến môi trường WORKER_MODEL (export trước khi dispatch) sẽ GHI ĐÈ.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_CONF="$KIT_DIR/roles.conf"
CONFIG_DIR="$HOME/.config/opencode"
PROFILE=""
POSITIONAL=()

while [ $# -gt 0 ]; do
  case "$1" in
    --config-dir) CONFIG_DIR="${2:?--config-dir cần đường dẫn}"; shift 2 ;;
    --config-dir=*) CONFIG_DIR="${1#*=}"; shift ;;
    --profile) PROFILE="${2:?--profile cần tên}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    --*) echo "set-model.sh: flag không hiểu: $1" >&2; exit 2 ;;
    *) POSITIONAL+=("$1"); shift ;;
  esac
done

JSON="$CONFIG_DIR/opencode.json"
AGENTS_DIR="$CONFIG_DIR/agents"
TS="$(date +%Y%m%d-%H%M%S)"
BACKED_UP=""

[ -f "$JSON" ] || { echo "set-model.sh: không thấy $JSON" >&2; exit 1; }
[ -f "$ROLES_CONF" ] || { echo "set-model.sh: không thấy $ROLES_CONF" >&2; exit 1; }
command -v python3 >/dev/null || { echo "set-model.sh: thiếu python3" >&2; exit 1; }

ROLE_NAMES=(); ROLE_TARGETS=(); ROLE_DESCS=()
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  ROLE_NAMES+=("${line%%|*}")
  rest="${line#*|}"
  ROLE_TARGETS+=("${rest%%|*}")
  ROLE_DESCS+=("${rest#*|}")
done < "$ROLES_CONF"

role_index() { # in ra index hoặc exit 1
  local i
  for i in "${!ROLE_NAMES[@]}"; do
    [ "${ROLE_NAMES[$i]}" = "$1" ] && { echo "$i"; return 0; }
  done
  return 1
}

valid_name() { [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]; }

backup_file() { # sao lưu 1 lần/file/lần chạy
  local f="$1"
  case "$BACKED_UP" in *" $f "*) return ;; esac
  cp "$f" "$f.bak-$TS"
  BACKED_UP="$BACKED_UP $f"
  echo "  backup: $f.bak-$TS"
}

validate_model() { # provider/model[#variant] — chỉ cảnh báo nếu không có trong opencode.json
  python3 - "$JSON" "$1" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
model = sys.argv[2].split("#", 1)[0]
prov, _, mdl = model.partition("/")
models = (d.get("provider", {}).get(prov, {}).get("models") or {})
if not mdl or mdl not in models:
    known = ", ".join(f"{p}/{m}" for p, pv in d.get("provider", {}).items() for m in (pv.get("models") or {}))
    print(f"  CẢNH BÁO: '{model}' không có trong opencode.json provider models.")
    print(f"  Model hiện có: {known}")
PYEOF
}

get_current() { # get_current <target> -> in model hiện tại (rỗng nếu không có)
  local t="$1"
  case "$t" in
    md:*)
      local f="$AGENTS_DIR/${t#md:}.md"
      [ -f "$f" ] && sed -n 's/^model:[[:space:]]*//p' "$f" | head -1
      ;;
    json:*)
      python3 - "$JSON" "${t#json:}" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
o = d
for k in sys.argv[2].split("."):
    if not isinstance(o, dict) or k not in o:
        sys.exit(0)
    o = o[k]
print(o if isinstance(o, str) else "")
PYEOF
      ;;
  esac
}

apply_target() { # apply_target <target> <model>
  local t="$1" model="$2"
  case "$t" in
    md:*)
      local f="$AGENTS_DIR/${t#md:}.md"
      [ -f "$f" ] || { echo "set-model.sh: không thấy $f" >&2; return 1; }
      backup_file "$f"
      python3 - "$f" "$model" <<'PYEOF'
import re, sys
path, model = sys.argv[1], sys.argv[2]
txt = open(path).read()
m = re.match(r"(?s)^---\n(.*?)\n---", txt)
if not m:
    sys.exit("set-model.sh: file không có frontmatter: " + path)
fm = m.group(1)
if re.search(r"^model:.*$", fm, re.M):
    fm = re.sub(r"^model:.*$", lambda _: "model: " + model, fm, count=1, flags=re.M)
else:
    fm = fm + "\nmodel: " + model
open(path, "w").write(txt[:m.start(1)] + fm + txt[m.end(1):])
PYEOF
      ;;
    json:*)
      backup_file "$JSON"
      python3 - "$JSON" "${t#json:}" "$model" <<'PYEOF'
import json, sys
path, dotted, model = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path))
keys = dotted.split(".")
o = d
for k in keys[:-1]:
    o = o.setdefault(k, {})
o[keys[-1]] = model
with open(path, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF
      ;;
    *) echo "set-model.sh: target lạ: $t" >&2; return 1 ;;
  esac
}

apply_one() { # <role|agent> <provider/model[#variant]>
  local name="$1" model="$2"
  valid_name "$name" || { echo "set-model.sh: tên role/agent không hợp lệ: '$name'" >&2; return 1; }
  case "$model" in */*) ;; *) echo "set-model.sh: model phải dạng provider/model, nhận: '$model'" >&2; return 1 ;; esac
  validate_model "$model"
  local idx
  if idx="$(role_index "$name")"; then
    local targets="${ROLE_TARGETS[$idx]}"
    local IFS_SAVE="$IFS"; IFS=','
    local tl; for tl in $targets; do apply_target "$tl" "$model"; done
    IFS="$IFS_SAVE"
    echo "  $name -> $model (${ROLE_TARGETS[$idx]})"
  elif [ -f "$AGENTS_DIR/$name.md" ]; then
    apply_target "md:$name" "$model"
    echo "  $name -> $model (agents/$name.md)"
  elif [ -n "$(get_current "json:agents.$name.model")" ]; then
    apply_target "json:agents.$name.model" "$model"
    echo "  $name -> $model (opencode.json agents)"
  else
    echo "set-model.sh: role/agent không tồn tại: '$name'" >&2
    return 1
  fi
}

cmd_list() {
  echo "  ROLE (roles.conf):"
  local i cur
  for i in "${!ROLE_NAMES[@]}"; do
    local first_target="${ROLE_TARGETS[$i]%%,*}"
    cur="$(get_current "$first_target")"
    [ -z "$cur" ] && cur="(kế thừa main)"
    local extra=""
    case "${ROLE_TARGETS[$i]}" in *,*) extra=" [+${ROLE_TARGETS[$i]#*,} cùng set]" ;; esac
    printf "  %-13s %-38s %s%s\n" "${ROLE_NAMES[$i]}" "$cur" "${ROLE_DESCS[$i]%% —*}" "$extra"
  done
  echo
  echo "  Agent khác trong opencode.json agents block (không thuộc role):"
  python3 - "$JSON" "$ROLES_CONF" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
covered = set()
for line in open(sys.argv[2]):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    for t in line.split("|")[1].split(","):
        t = t.strip()
        if t.startswith("json:agents."):
            covered.add(t.split(".")[1])
for k in sorted(d.get("agents") or {}):
    if k in covered:
        continue
    v = d["agents"][k] or {}
    model = v.get("model") or ("(disabled)" if v.get("disabled") else "(kế thừa main)")
    print(f"  {k:<13} {model}")
PYEOF
}

list_models() { # in "index) provider/model" cho mọi model trong opencode.json
  python3 - "$JSON" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
i = 1
for p, pv in d.get("provider", {}).items():
    for m in (pv.get("models") or {}):
        print(f"{i}) {p}/{m}")
        i += 1
PYEOF
}

model_by_index() { # model_by_index <n> -> provider/model
  python3 - "$JSON" "$1" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
want = int(sys.argv[2])
i = 1
for p, pv in d.get("provider", {}).items():
    for m in (pv.get("models") or {}):
        if i == want:
            print(f"{p}/{m}")
            sys.exit(0)
        i += 1
sys.exit(1)
PYEOF
}

env_name_for_role() { echo "KIT_MODEL_$(echo "$1" | tr 'a-z-' 'A-Z_')"; }

cmd_pick() {
  local interactive=0
  if [ -t 0 ] || [ "${KIT_FORCE_PROMPT:-0}" = "1" ]; then interactive=1; fi
  local models_text
  models_text="$(list_models)"
  if [ "$interactive" -eq 1 ]; then
    echo "  Model có sẵn (theo provider trong opencode.json):"
    echo "$models_text" | sed 's/^/    /'
    echo "  (mỗi role: nhập số, hoặc provider/model[#variant], Enter = giữ nguyên; env KIT_MODEL_<ROLE> ghi đè sẵn)"
  fi
  local i name choice cur chosen
  declare -a PICK_NAMES PICK_MODELS
  for i in "${!ROLE_NAMES[@]}"; do
    name="${ROLE_NAMES[$i]}"
    cur="$(get_current "${ROLE_TARGETS[$i]%%,*}")"
    local envar; envar="$(env_name_for_role "$name")"
    local preset="${!envar:-}"
    if [ -n "$preset" ]; then
      echo "  $name: $preset (từ env $envar)"
      chosen="$preset"
    elif [ "$interactive" -eq 1 ]; then
      printf "  %s [hiện: %s] — %s\n    chọn> " "$name" "${cur:-?}" "${ROLE_DESCS[$i]}"
      IFS= read -r choice || choice=""
      case "$choice" in
        "") chosen="$cur" ;;
        *[!0-9]*) chosen="$choice" ;;
        *) chosen="$(model_by_index "$choice")" || { echo "    số không hợp lệ — giữ nguyên"; chosen="$cur"; } ;;
      esac
    else
      chosen="$cur"
    fi
    [ -z "$chosen" ] && { echo "  $name: bỏ qua (chưa có model hiện tại)"; continue; }
    PICK_NAMES+=("$name"); PICK_MODELS+=("$chosen")
  done
  echo
  echo "  Áp dụng:"
  for i in "${!PICK_NAMES[@]}"; do
    apply_one "${PICK_NAMES[$i]}" "${PICK_MODELS[$i]}"
  done
  # Ghi profile kết quả để tái áp dụng
  local out="$CONFIG_DIR/kit-profile.env"
  {
    echo "# kit-profile.env — sinh bởi 'set-model.sh pick' / install.sh lúc $(date +%Y-%m-%d)"
    echo "# Tái áp dụng: set-model.sh --profile $out"
    for i in "${!PICK_NAMES[@]}"; do echo "${PICK_NAMES[$i]}=${PICK_MODELS[$i]}"; done
  } > "$out"
  echo
  echo "  TÓM TẮT role -> model (đã ghi $out):"
  for i in "${!PICK_NAMES[@]}"; do
    printf "    %-13s %s\n" "${PICK_NAMES[$i]}" "${PICK_MODELS[$i]}"
  done
}

apply_profile() { # <đường dẫn file env>
  local pfile="$1" line
  [ -f "$pfile" ] || { echo "set-model.sh: không thấy profile: $pfile" >&2; exit 1; }
  echo "áp profile: $pfile"
  local touches_worker=0
  while IFS= read -r line; do
    # bỏ comment cả dòng và comment cuối dòng (sau khoảng trắng); GIỮ #variant trong giá trị
    line="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*#.*$//; s/[[:space:]]+#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//')"
    [ -n "$line" ] || continue
    local agent="${line%%=*}" model="${line#*=}"
    [ "$agent" = "$model" ] && { echo "  bỏ qua dòng lạ: $line" >&2; continue; }
    [ "$agent" = "worker" ] && touches_worker=1
    apply_one "$agent" "$model"
  done < "$pfile"
  [ "$touches_worker" -eq 1 ] && echo "  ghi nhớ: WORKER_MODEL env (worker-kit dispatch.sh) vẫn ghi đè model của worker"
}

cmd_snapshot_profile() { # ghi kit-profile.env từ state hiện tại (không đổi gì)
  local out="$CONFIG_DIR/kit-profile.env" i cur
  {
    echo "# kit-profile.env — chụp state hiện tại lúc $(date +%Y-%m-%d)"
    echo "# Tái áp dụng: set-model.sh --profile $out"
    for i in "${!ROLE_NAMES[@]}"; do
      cur="$(get_current "${ROLE_TARGETS[$i]%%,*}")"
      [ -n "$cur" ] && echo "${ROLE_NAMES[$i]}=$cur"
    done
  } > "$out"
  echo "  đã ghi $out"
}

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

# --- main -------------------------------------------------------------------
echo "set-model.sh (config: $CONFIG_DIR)"
if [ -n "$PROFILE" ]; then
  case "$PROFILE" in */*) apply_profile "$PROFILE" ;; *) apply_profile "$KIT_DIR/profiles/$PROFILE.env" ;; esac
elif [ "${#POSITIONAL[@]}" -ge 1 ] && [ "${POSITIONAL[0]}" = "list" ]; then
  cmd_list
elif [ "${#POSITIONAL[@]}" -ge 1 ] && [ "${POSITIONAL[0]}" = "pick" ]; then
  cmd_pick
elif [ "${#POSITIONAL[@]}" -ge 1 ] && [ "${POSITIONAL[0]}" = "snapshot-profile" ]; then
  cmd_snapshot_profile
elif [ "${#POSITIONAL[@]}" -eq 2 ]; then
  apply_one "${POSITIONAL[0]}" "${POSITIONAL[1]}"
  [ "${POSITIONAL[0]}" = "worker" ] && echo "  ghi nhớ: WORKER_MODEL env (worker-kit dispatch.sh) vẫn ghi đè model của worker"
else
  usage
fi
