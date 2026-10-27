#!/usr/bin/env bash
# install.sh — khôi phục setup OpenCode + Finder từ repo này về $HOME.
#
#   ./install.sh                       cài đầy đủ (trừ LaunchAgent); hỏi chọn model nếu chạy trong TTY
#   ./install.sh --dry-run             chỉ in ra sẽ làm gì, không đụng vào đĩa
#   ./install.sh --no-finder           bỏ qua bước tải binary finder
#   ./install.sh --with-services       cài + bootstrap LaunchAgent tavily-key-pool
#   ./install.sh --pick-models         mở picker chọn model theo từng role (roles.conf)
#   ./install.sh --profile NAME        áp profiles/NAME.env, không hỏi
#   ./install.sh --no-prompt           không hỏi gì cả — giữ profile default (hoặc env KIT_MODEL_*)
#
# Biến môi trường:
#   KIT_SKIP_NPM=1         bỏ qua mọi bước npm install
#   KIT_FORCE_FINDER=1     tải lại finder dù đã có
#   KIT_FINDER_URL=...     override URL tải finder (vd file:///... để test)
#   KIT_MODEL_<ROLE>=...   set model cho role (vd KIT_MODEL_WORKER=vua/kimi-k3); role xem roles.conf
#   KIT_USER_NAME=...      tên hiển thị khôi phục vào AGENTS.md (kèm KIT_USER_GENDER, KIT_USER_ADDRESS)
#   KIT_FORCE_PROMPT=1     ép hỏi đáp qua stdin kể cả khi không phải TTY (để test pipe)
#
# Script idempotent: chạy lại nhiều lần an toàn. Không bao giờ ghi đè file secret đã có.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=kit.conf
. "$KIT_DIR/kit.conf"

DRY=0
NO_FINDER=0
WITH_SERVICES=0
PICK=0
NO_PROMPT=0
PROFILE=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --no-finder) NO_FINDER=1 ;;
    --with-services) WITH_SERVICES=1 ;;
    --pick-models) PICK=1 ;;
    --no-prompt) NO_PROMPT=1 ;;
    --profile=*) PROFILE="${1#*=}" ;;
    --profile) echo "install.sh: --profile cần dạng --profile=NAME" >&2; exit 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: tham số không hiểu: $arg" >&2; exit 2 ;;
  esac
done

run() {
  if [ "$DRY" -eq 1 ]; then
    echo "  [dry-run] $*"
  else
    "$@"
  fi
}

interactive() { [ -t 0 ] || [ "${KIT_FORCE_PROMPT:-0}" = "1" ]; }

# Thay chuỗi trong mọi file text dưới $1 (python — an toàn &, |, unicode). Dùng: subst_texts DIR FROM TO
subst_texts() {
  SUBST_FROM="$2" SUBST_TO="$3" python3 - "$1" <<'PYEOF'
import os, sys
root, frm, to = sys.argv[1], os.environ["SUBST_FROM"], os.environ["SUBST_TO"]
for dp, dn, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        try:
            txt = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        if frm in txt:
            open(p, "w", encoding="utf-8").write(txt.replace(frm, to))
PYEOF
}

BAK_DIRS=""
backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local bak="${target}.bak-${TS}"
    if [ "$DRY" -eq 1 ]; then
      echo "  [dry-run] mv $target $bak (chmod 700)"
    else
      mv "$target" "$bak"
      chmod 700 "$bak"
    fi
    BAK_DIRS="$BAK_DIRS $bak"
    echo "  backup: $bak (chmod 700)"
  fi
}

echo "==> 1/8 Kiểm tra phụ thuộc"
missing=0
for dep in git python3 rsync; do
  if ! command -v "$dep" >/dev/null; then
    echo "  THIẾU: $dep" >&2; missing=1
  fi
done
[ "$missing" -eq 1 ] && { echo "install.sh: cài các gói trên rồi chạy lại" >&2; exit 1; }
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "  cảnh báo: thiếu node/npm — sẽ bỏ qua bước npm install (cài qua homebrew: brew install node)"
fi
if ! command -v opencode >/dev/null; then
  echo "  gợi ý: opencode chưa có — cài bằng: curl -fsSL https://opencode.ai/install | bash"
fi

echo "==> 2/8 Sao lưu target cũ (nếu có) + copy snapshot"
TS="$(date +%Y%m%d-%H%M%S)"
for sub in .config/opencode .claude/skills .agents/skills; do
  src="$KIT_DIR/home/$sub"
  dst="$HOME/$sub"
  [ -d "$src" ] || { echo "  bỏ qua (snapshot không có): $sub"; continue; }
  backup_if_exists "$dst"
  run mkdir -p "$(dirname "$dst")"
  run rsync -a "$src/" "$dst/"
  echo "  cài: $sub"
done

if [ "$DRY" -eq 0 ]; then
  # Thay __HOME__ -> $HOME và placeholder path ví dụ trong các file text vừa cài.
  for sub in .config/opencode .claude/skills .agents/skills; do
    [ -d "$HOME/$sub" ] || continue
    subst_texts "$HOME/$sub" "__HOME__" "$HOME"
    SUBST_ROOT="$HOME/$sub" python3 - <<'PYEOF'
import os, re
root = os.environ["SUBST_ROOT"]
pat = re.compile(r"__EXAMPLE_REPO(?:_\d+)?__")
for dp, dn, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        try:
            txt = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        if pat.search(txt):
            open(p, "w", encoding="utf-8").write(pat.sub("/path/to/your/repo", txt))
PYEOF
  done
  echo "  đã thay __HOME__ -> $HOME"
else
  echo "  [dry-run] sẽ thay __HOME__ -> \$HOME và __EXAMPLE_REPO__ -> /path/to/your/repo"
fi

echo "==> 3/8 Danh tính người dùng (AGENTS.md / teach)"
CFG="$HOME/.config/opencode"
USER_ENV="$CFG/kit-user.env"
# Ưu tiên: env KIT_USER_* > file kit-user.env đã lưu từ lần cài trước > hỏi (TTY) > text trung lập
if [ -f "$USER_ENV" ]; then
  # file do chính install.sh ghi (key=value có quote) — đọc lại làm giá trị mặc định
  while IFS= read -r ln; do
    case "$ln" in
      KIT_USER_NAME=*)    [ -z "${KIT_USER_NAME:-}" ]    && KIT_USER_NAME="$(printf '%s' "${ln#*=}" | sed 's/^"//; s/"$//')" ;;
      KIT_USER_GENDER=*)  [ -z "${KIT_USER_GENDER:-}" ]  && KIT_USER_GENDER="$(printf '%s' "${ln#*=}" | sed 's/^"//; s/"$//')" ;;
      KIT_USER_ADDRESS=*) [ -z "${KIT_USER_ADDRESS:-}" ] && KIT_USER_ADDRESS="$(printf '%s' "${ln#*=}" | sed 's/^"//; s/"$//')" ;;
    esac
  done < "$USER_ENV"
fi
if [ -z "${KIT_USER_NAME:-}" ] && interactive && [ "$NO_PROMPT" -eq 0 ] && [ "$DRY" -eq 0 ]; then
  echo "  Nhập thông tin hiển thị (Enter hết = dùng text trung lập):"
  printf "  Tên của bạn: "; IFS= read -r KIT_USER_NAME || KIT_USER_NAME=""
  if [ -n "$KIT_USER_NAME" ]; then
    printf "  Giới tính/xưng hô (vd NỮ): "; IFS= read -r KIT_USER_GENDER || KIT_USER_GENDER=""
    printf "  Cách gọi ngắn (vd tên riêng): "; IFS= read -r KIT_USER_ADDRESS || KIT_USER_ADDRESS=""
  fi
fi
if [ "$DRY" -eq 1 ]; then
  echo "  [dry-run] sẽ điền danh tính vào AGENTS.md/teach.md (hoặc text trung lập)"
elif [ -z "${KIT_USER_NAME:-}" ]; then
  echo "  không có thông tin — dùng text trung lập"
  python3 - "$CFG" <<'PYEOF'
import os, sys
root = sys.argv[1]
neutral = '- Người dùng: chưa cấu hình — xưng hô trung lập "bạn", không suy đoán giới tính.'
for dp, dn, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        try:
            txt = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        if "__USER_" not in txt:
            continue
        lines = [neutral if "__USER_NAME__" in ln and ln.lstrip().startswith("-") else ln
                 for ln in txt.splitlines()]
        txt = "\n".join(lines) + ("\n" if txt.endswith("\n") else "")
        txt = (txt.replace("__USER_ADDRESS__", "bạn")
                  .replace("__USER_NAME__", "bạn")
                  .replace("__USER_GENDER__", "người dùng"))
        open(p, "w", encoding="utf-8").write(txt)
PYEOF
else
  KIT_USER_GENDER="${KIT_USER_GENDER:-NGƯỜI DÙNG}"
  KIT_USER_ADDRESS="${KIT_USER_ADDRESS:-$KIT_USER_NAME}"
  subst_texts "$CFG" "__USER_NAME__" "$KIT_USER_NAME"
  subst_texts "$CFG" "__USER_GENDER__" "$KIT_USER_GENDER"
  subst_texts "$CFG" "__USER_ADDRESS__" "$KIT_USER_ADDRESS"
  {
    echo "# kit-user.env — danh tính người dùng cho các lần cài lại (chmod 600, không sync)"
    printf 'KIT_USER_NAME="%s"\n' "$KIT_USER_NAME"
    printf 'KIT_USER_GENDER="%s"\n' "$KIT_USER_GENDER"
    printf 'KIT_USER_ADDRESS="%s"\n' "$KIT_USER_ADDRESS"
  } > "$USER_ENV"
  chmod 600 "$USER_ENV"
  echo "  đã điền danh tính (lưu $USER_ENV, chmod 600)"
fi

echo "==> 4/8 Chọn model theo role (roles.conf)"
SET_MODEL="$KIT_DIR/set-model.sh"
MODE="default"
if [ -n "$PROFILE" ]; then
  MODE="profile"
elif [ "$PICK" -eq 1 ]; then
  MODE="pick"
else
  env_hits=0
  while IFS='|' read -r role _rest; do
    case "$role" in ''|\#*) continue ;; esac
    envar="KIT_MODEL_$(printf '%s' "$role" | tr 'a-z-' 'A-Z_')"
    [ -n "${!envar:-}" ] && env_hits=$((env_hits + 1))
  done < "$KIT_DIR/roles.conf"
  if [ "$env_hits" -gt 0 ]; then
    MODE="env"
  elif [ "$NO_PROMPT" -eq 1 ]; then
    MODE="default"
  elif interactive && [ "$DRY" -eq 0 ]; then
    printf "  Chọn model theo profile (d=default/c=cheap/s=strong) hay tuỳ chỉnh từng role? [d/c/s/t, Enter=d] "
    IFS= read -r ans || ans=""
    case "$ans" in
      c|cheap) MODE="profile"; PROFILE="cheap" ;;
      s|strong) MODE="profile"; PROFILE="strong" ;;
      t|custom) MODE="pick" ;;
      *) MODE="default" ;;
    esac
  fi
fi
case "$MODE" in
  profile)
    echo "  áp profile: $PROFILE"
    if [ "$DRY" -eq 0 ]; then
      "$SET_MODEL" --config-dir "$CFG" --profile "$PROFILE"
      "$SET_MODEL" --config-dir "$CFG" snapshot-profile
    else echo "  [dry-run] set-model.sh --profile $PROFILE" ; fi
    ;;
  env)
    echo "  áp từ env KIT_MODEL_*:"
    if [ "$DRY" -eq 0 ]; then
      while IFS='|' read -r role _rest; do
        case "$role" in ''|\#*) continue ;; esac
        envar="KIT_MODEL_$(printf '%s' "$role" | tr 'a-z-' 'A-Z_')"
        val="${!envar:-}"
        [ -n "$val" ] && "$SET_MODEL" --config-dir "$CFG" "$role" "$val"
      done < "$KIT_DIR/roles.conf"
      "$SET_MODEL" --config-dir "$CFG" snapshot-profile
    else echo "  [dry-run] áp $env_hits role từ env" ; fi
    ;;
  pick)
    if [ "$DRY" -eq 1 ]; then echo "  [dry-run] mở picker"; else "$SET_MODEL" --config-dir "$CFG" pick; fi
    ;;
  default)
    echo "  giữ profile default (mapping trong snapshot sẵn là default)"
    ;;
esac

echo "==> 5/8 npm install"
if [ "$DRY" -eq 1 ]; then
  echo "  [dry-run] bỏ qua npm install"
elif [ "${KIT_SKIP_NPM:-0}" = "1" ]; then
  echo "  KIT_SKIP_NPM=1 — bỏ qua"
elif ! command -v npm >/dev/null; then
  echo "  thiếu npm — bỏ qua (chạy lại sau khi cài node)"
else
  NPM_DIRS=()
  [ -f "$HOME/.config/opencode/package.json" ] && NPM_DIRS+=("$HOME/.config/opencode")
  [ -f "$HOME/.config/opencode/tools/tavily-key-pool/package.json" ] && NPM_DIRS+=("$HOME/.config/opencode/tools/tavily-key-pool")
  while IFS= read -r pj; do
    NPM_DIRS+=("$(dirname "$pj")")
  done < <(find "$HOME/.config/opencode/skills" "$HOME/.claude/skills" "$HOME/.agents/skills" \
             -maxdepth 2 -name package.json -not -path '*/node_modules/*' 2>/dev/null || true)
  for d in ${NPM_DIRS[@]+"${NPM_DIRS[@]}"}; do
    echo "  npm install: $d"
    (cd "$d" && npm install --no-fund --no-audit) || echo "  CẢNH BÁO: npm install lỗi ở $d — chạy lại tay sau"
  done
fi

echo "==> 6/8 Binary finder ($FINDER_ASSET_NAME @ $FINDER_RELEASE_TAG)"
FINDER_BIN="$HOME/.local/bin/finder"
if [ "$NO_FINDER" -eq 1 ]; then
  echo "  --no-finder — bỏ qua"
elif [ -x "$FINDER_BIN" ] && [ "${KIT_FORCE_FINDER:-0}" != "1" ]; then
  echo "  đã có $FINDER_BIN — bỏ qua (KIT_FORCE_FINDER=1 để tải lại)"
elif [ "$DRY" -eq 1 ]; then
  echo "  [dry-run] tải finder -> $FINDER_BIN rồi kiểm sha256"
else
  run mkdir -p "$HOME/.local/bin"
  TMP_DIR="$(mktemp -d -t finder-dl)"
  TMP_FINDER="$TMP_DIR/$FINDER_ASSET_NAME"
  URL="${KIT_FINDER_URL:-https://github.com/$KIT_REPO/releases/download/$FINDER_RELEASE_TAG/$FINDER_ASSET_NAME}"
  if curl -fsSL "$URL" -o "$TMP_FINDER"; then
    echo "  tải ok qua curl"
  elif command -v gh >/dev/null && gh release download "$FINDER_RELEASE_TAG" --repo "$KIT_REPO" --pattern "$FINDER_ASSET_NAME" --dir "$TMP_DIR" --clobber; then
    echo "  tải ok qua gh"
  else
    rm -rf "$TMP_DIR"
    echo "  CẢNH BÁO: không tải được finder — tải tay: $URL" >&2
    TMP_FINDER=""
  fi
  if [ -n "$TMP_FINDER" ] && [ -f "$TMP_FINDER" ]; then
    actual_sha="$(shasum -a 256 "$TMP_FINDER" | awk '{print $1}')"
    if [ -n "${FINDER_SHA256:-}" ] && [ "$actual_sha" != "$FINDER_SHA256" ]; then
      echo "  CẢNH BÁO: sha256 KHÔNG khớp (kit.conf: ${FINDER_SHA256:0:16}..., tải về: ${actual_sha:0:16}...) — HUỶ cài finder" >&2
      rm -rf "$TMP_DIR"
    else
      chmod +x "$TMP_FINDER"
      mv "$TMP_FINDER" "$FINDER_BIN"
      rm -rf "$TMP_DIR"
      echo "  cài: $FINDER_BIN (sha256 khớp)"
    fi
  fi
fi

echo "==> 7/8 Finder settings + services"
if [ -f "$HOME/.finder/settings.json" ]; then
  echo "  ~/.finder/settings.json đã tồn tại — giữ nguyên"
else
  run mkdir -p "$HOME/.finder"
  run cp "$KIT_DIR/templates/finder-settings.json" "$HOME/.finder/settings.json"
  echo "  cài: ~/.finder/settings.json (từ template — còn trường <REDACTED> phải điền, xem bước 8)"
fi
if [ "$WITH_SERVICES" -eq 0 ]; then
  echo "  LaunchAgent: bỏ qua (thêm --with-services để cài)"
else
  PLIST_DST="$HOME/Library/LaunchAgents/local.tavily-key-pool.plist"
  run mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.tavily-key-pool/logs"
  if [ "$DRY" -eq 1 ]; then
    echo "  [dry-run] render templates/local.tavily-key-pool.plist -> $PLIST_DST + launchctl bootstrap"
  else
    subst_texts_plist() { SUBST_FROM="$2" SUBST_TO="$3" python3 - "$1" <<'PYEOF'
import os, sys
p, frm, to = sys.argv[1], os.environ["SUBST_FROM"], os.environ["SUBST_TO"]
open(p, "w", encoding="utf-8").write(open(p, encoding="utf-8").read().replace(frm, to))
PYEOF
    }
    cp "$KIT_DIR/templates/local.tavily-key-pool.plist" "$PLIST_DST"
    subst_texts_plist "$PLIST_DST" "__HOME__" "$HOME"
    [ -x /opt/homebrew/bin/node ] || echo "  cảnh báo: plist trỏ /opt/homebrew/bin/node nhưng file không có — cài node qua homebrew"
    launchctl bootout "gui/$(id -u)/local.tavily-key-pool" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST_DST" \
      && echo "  bootstrap ok: local.tavily-key-pool" \
      || echo "  CẢNH BÁO: launchctl bootstrap lỗi — thử: launchctl bootstrap gui/$(id -u) $PLIST_DST"
  fi
fi

echo "==> 8/8 Checklist secrets (repo public KHÔNG chứa secret — tự điền)"
if [ "$DRY" -eq 0 ]; then
  mkdir -p "$HOME/.secrets/opencode"
  chmod 700 "$HOME/.secrets" "$HOME/.secrets/opencode" 2>/dev/null || true
else
  echo "  [dry-run] mkdir -p ~/.secrets/opencode (chmod 700)"
fi

secret_note() { # name + mô tả ngắn
  local name="$1" desc="$2"
  if [ -s "$HOME/.secrets/opencode/$name" ]; then
    echo "  [ok]      ~/.secrets/opencode/$name"
  else
    echo "  [THIẾU]   ~/.secrets/opencode/$name — $desc"
  fi
}
echo "  --- ~/.secrets/opencode/ ---"
secret_needs=0
for entry in \
  "vua-apikey|API key provider 'vua' (https://llmrouter.space) — trong opencode.json" \
  "localproxyapi-apikey|API key local proxy http://127.0.0.1:8317 — trong opencode.json" \
  "context7-apikey|API key Context7 MCP — trong opencode.json (mcp.context7.environment)" \
  "finder-token|Bearer token Finder MCP — opencode.json mcp.finder.headers.Authorization"
do
  name="${entry%%|*}"; desc="${entry#*|}"
  [ -s "$HOME/.secrets/opencode/$name" ] || secret_needs=$((secret_needs + 1))
  secret_note "$name" "$desc"
done

echo "  --- khác ---"
if [ -f "$HOME/.config/opencode/tools/tavily-key-pool/config.yaml" ]; then
  echo "  [ok]      tools/tavily-key-pool/config.yaml"
else
  echo "  [THIẾU]   tools/tavily-key-pool/config.yaml — cp config.example.yaml config.yaml rồi chỉnh"
  secret_needs=$((secret_needs + 1))
fi

# Liệt kê các trường <REDACTED> trong template finder settings cần điền tay.
python3 - "$KIT_DIR/templates/finder-settings.json" <<'PYEOF' || true
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
out = []
def walk(o, p=""):
    if isinstance(o, dict):
        for k, v in o.items():
            walk(v, f"{p}.{k}" if p else k)
    elif isinstance(o, list):
        if any(x == "<REDACTED>" for x in o):
            out.append(p)
    elif o == "<REDACTED>":
        out.append(p)
walk(d)
if out:
    print("  --- ~/.finder/settings.json: điền các trường <REDACTED> ---")
    for p in out:
        print(f"  [THIẾU]   {p}")
PYEOF

echo
if [ "$secret_needs" -gt 0 ]; then
  echo "  => còn $secret_needs mục secrets cần điền tay (xem README.md mục Secrets)"
else
  echo "  => secrets đầy đủ"
fi
if [ -n "$BAK_DIRS" ]; then
  echo
  echo "  Backup đã tạo (chmod 700 — xoá tay khi chắc không cần):"
  for b in $BAK_DIRS; do echo "    $b"; done
fi
echo "==> Xong."
