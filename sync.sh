#!/usr/bin/env bash
# sync.sh — đồng bộ config OpenCode + Finder live vào snapshot trong repo này.
#
#   ./sync.sh           rsync -> snapshot, __HOME__ hoá, ẨN DANH hoá, làm sạch secret, quét secret
#   ./sync.sh --push    như trên, rồi git add/commit/push
#
# Không bao giờ ghi ngược vào ~/.config, ~/.claude, ~/.agents, ~/.finder, ~/.secrets, ~/Library.
# Cặp thay thế ẩn danh nằm ở .kit-local.env (gitignored, tự tạo lần sync đầu từ dữ liệu live).
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_ENV="$KIT_DIR/.kit-local.env"
PUSH=0

for arg in "$@"; do
  case "$arg" in
    --push) PUSH=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "sync.sh: tham số không hiểu: $arg" >&2; exit 2 ;;
  esac
done

SRC_OPENCODE="$HOME/.config/opencode"
SRC_CLAUDE_SKILLS="$HOME/.claude/skills"
SRC_AGENTS_SKILLS="$HOME/.agents/skills"
FINDER_SETTINGS="$HOME/.finder/settings.json"

SNAP_OPENCODE="$KIT_DIR/home/.config/opencode"
SNAP_CLAUDE_SKILLS="$KIT_DIR/home/.claude/skills"
SNAP_AGENTS_SKILLS="$KIT_DIR/home/.agents/skills"

# File trong repo được phép match secret-pattern (đã kiểm chứng là giả). Đường dẫn tương đối từ gốc repo.
ALLOWLIST=(
  # Fixture test cho hàm redact của skill management-report-docx: chuỗi ghp_ + bảng chữ cái, hoàn toàn giả.
  "home/.config/opencode/skills/management-report-docx/scripts/test_report_docx.py"
)

echo "==> 1/8 Kiểm tra nguồn"
for d in "$SRC_OPENCODE" "$SRC_CLAUDE_SKILLS" "$SRC_AGENTS_SKILLS"; do
  [ -d "$d" ] || { echo "sync.sh: thiếu thư mục nguồn: $d" >&2; exit 1; }
done
command -v rsync  >/dev/null || { echo "sync.sh: thiếu rsync" >&2; exit 1; }
command -v python3 >/dev/null || { echo "sync.sh: thiếu python3" >&2; exit 1; }

echo "==> 2/8 rsync live -> snapshot"
mkdir -p "$SNAP_OPENCODE" "$SNAP_CLAUDE_SKILLS" "$SNAP_AGENTS_SKILLS"

# Exclude chung: node_modules (29MB+ trong brave-search), cache python, log, rác macOS, bản .bak, .git lồng trong skill.
# Exclude riêng opencode: backups/, agents-bak/, service.json, config.yaml của tavily-key-pool (chứa API key),
# và /.gitignore ở gốc config (file đó ignore package.json — phá snapshot).
rsync -a --delete --delete-excluded \
  --exclude='.DS_Store' --exclude='node_modules/' --exclude='__pycache__/' --exclude='*.pyc' \
  --exclude='*.log' --exclude='*.bak*' --exclude='.git/' \
  --exclude='/backups/' --exclude='/agents-bak/' --exclude='/.gitignore' \
  --exclude='service.json' \
  --exclude='/tools/tavily-key-pool/config.yaml' \
  "$SRC_OPENCODE/" "$SNAP_OPENCODE/"

rsync -a --delete --delete-excluded \
  --exclude='.DS_Store' --exclude='node_modules/' --exclude='__pycache__/' --exclude='*.pyc' \
  --exclude='*.log' --exclude='*.bak*' --exclude='.git/' \
  "$SRC_CLAUDE_SKILLS/" "$SNAP_CLAUDE_SKILLS/"

rsync -a --delete --delete-excluded \
  --exclude='.DS_Store' --exclude='node_modules/' --exclude='__pycache__/' --exclude='*.pyc' \
  --exclude='*.log' --exclude='*.bak*' --exclude='.git/' \
  "$SRC_AGENTS_SKILLS/" "$SNAP_AGENTS_SKILLS/"

echo "==> 3/8 Thay \$HOME -> __HOME__ trong file text của snapshot (python, an toàn ký tự đặc biệt)"
HOME_REAL="$HOME" python3 - "$KIT_DIR/home" <<'PYEOF'
import os, sys
root, frm = sys.argv[1], os.environ["HOME_REAL"]
n = 0
for dp, dn, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        try:
            txt = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        if frm in txt:
            open(p, "w", encoding="utf-8").write(txt.replace(frm, "__HOME__"))
            n += 1
print(f"    đã thay trong {n} file")
PYEOF

echo "==> 4/8 Ẩn danh hoá (PII + path dự án khách)"
# .kit-local.env: tạo lần đầu từ dữ liệu LIVE (không hardcode PII trong script), chmod 600, gitignored.
if [ ! -f "$LOCAL_ENV" ]; then
  echo "    tạo $LOCAL_ENV từ dữ liệu live..."
  LIVE_AGENTS_MD="$SRC_OPENCODE/AGENTS.md" LIVE_TEACH_MD="$SRC_OPENCODE/agents/teach.md" \
  SRC_OPENCODE="$SRC_OPENCODE" SRC_CLAUDE_SKILLS="$SRC_CLAUDE_SKILLS" SRC_AGENTS_SKILLS="$SRC_AGENTS_SKILLS" \
  python3 - "$LOCAL_ENV" <<'PYEOF'
import os, re, sys

out = sys.argv[1]
fullname = gender = address = ""
mddir = os.environ.get("LIVE_AGENTS_MD", "")
if os.path.isfile(mddir):
    txt = open(mddir, encoding="utf-8").read()
    m = re.search(r'Tên:\s*(.+?)\s*—\s*([^.\n]+)\.', txt)
    if m:
        fullname, gender = m.group(1).strip(), m.group(2).strip()
    m = re.search(r'gọi\s*"(.+?)"\s*hoặc', txt)
    if m:
        address = m.group(1).strip()

lines = [
    "# .kit-local.env — cặp thay thế ẨN DANH, chứa PII thật — KHÔNG commit (đã gitignore).",
    "# Tự tạo lần sync đầu từ dữ liệu live; sửa tay nếu cần thêm/bớt cặp.",
    "# Format pipe: KEY|giá trị live   hoặc   SUB|chuỗi live|chuỗi thay trong snapshot",
    f"USER_FULLNAME|{fullname}",
    f"USER_GENDER|{gender}",
    f"USER_ADDRESS|{address}",
]

# Cụm câu trong teach.md chứa tên + giới tính -> thay bằng câu trung lập có placeholder.
teach = os.environ.get("LIVE_TEACH_MD", "")
if address and os.path.isfile(teach):
    for ln in open(teach, encoding="utf-8"):
        idx = ln.find(f"The learner is {address}")
        if idx >= 0:
            rest = ln[idx:].rstrip("\n")
            sents = rest.split(". ")
            seg = sents[0] + "."
            # gom thêm câu tiếp theo nếu là mô tả cá nhân (She/He/They is ...)
            if len(sents) > 1 and re.match(r"(?i)^(she|he|they)\b", sents[1]):
                seg += " " + sents[1].rstrip(".") + "."
            neutral = 'The learner is __USER_ADDRESS__ (call them "__USER_ADDRESS__" or "bạn").'
            lines.append(f"SUB|{seg}|{neutral}")
            break

# Quét path ổ rời (ổ ngoài macOS) và tên project trong các file text live.
roots = [os.environ.get("SRC_OPENCODE", ""), os.environ.get("SRC_CLAUDE_SKILLS", ""),
         os.environ.get("SRC_AGENTS_SKILLS", "")]
blobs = []
for root in roots:
    if not root or not os.path.isdir(root):
        continue
    for dp, dn, fn in os.walk(root):
        dn[:] = [d for d in dn if d not in ("node_modules", "__pycache__", ".git",
                                            "backups", "agents-bak")]
        for f in fn:
            if f.endswith((".bak", ".log", ".pyc")) or ".bak-" in f or f == "config.yaml":
                continue
            p = os.path.join(dp, f)
            try:
                blobs.append(open(p, encoding="utf-8").read())
            except (UnicodeDecodeError, OSError):
                pass
big = "\n".join(blobs)

VOL = "/" + "Volumes"  # ghép chuỗi để bản thân script không chứa path thật
paths = sorted(set(re.findall(re.escape(VOL) + r"/[A-Za-z0-9/_.-]+", big)), key=lambda s: (-len(s), s))
for i, p in enumerate(paths):
    ph = "__EXAMPLE_REPO__" if i == 0 else f"__EXAMPLE_REPO_{i+1}__"
    lines.append(f"SUB|{p}|{ph}")

# Tên project: (a) basename của mọi path ổ rời tìm được — chắc chắn có trong corpus;
# (b) basename của mọi THƯ MỤC con dưới MỌI thư mục cha của các path đó (bỏ file, tên ẩn).
# Chỉ nhận tên trông-giống-project (có -, _ hoặc chữ số) + xuất hiện như từ đứng một mình.
names = []
if paths:
    cands = set(os.path.basename(p.rstrip("/")) for p in paths)
    for wr in sorted({os.path.dirname(p) for p in paths}):
        if os.path.isdir(wr):
            for c in os.listdir(wr):
                if not c.startswith(".") and os.path.isdir(os.path.join(wr, c)):
                    cands.add(c)
    for c in sorted(cands):
        if len(c) < 4 or not re.search(r"[-_0-9]", c):
            continue
        if re.search(r"(?<![A-Za-z0-9_])" + re.escape(c) + r"(?![A-Za-z0-9_])", big):
            names.append(c)
# Tên project legacy chỉ còn trong worker-kit/lessons.md (repo gốc có thể đã xoá):
# lấy token ở cột 2 của bảng lessons (session name dạng "<project> <sub>").
lessons = os.path.join(os.environ.get("SRC_CLAUDE_SKILLS", ""), "worker-kit", "lessons.md")
if os.path.isfile(lessons):
    for ln in open(lessons, encoding="utf-8"):
        if not ln.startswith("|"):
            continue
        cols = [c.strip() for c in ln.strip().strip("|").split("|")]
        if len(cols) < 2:
            continue
        for tokn in cols[1].split():
            if re.fullmatch(r"[a-z0-9][a-z0-9_-]{2,}[a-z0-9]", tokn) and re.search(r"[-_0-9]", tokn):
                names.append(tokn)
    names = sorted(set(names))
import string
for i, c in enumerate(names):
    suffix = string.ascii_lowercase[i] if i < 26 else str(i)
    lines.append(f"SUB|{c}|project-{suffix}")

with open(out, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
os.chmod(out, 0o600)
print(f"    đã tạo: {len(paths)} path ổ rời, {len(names)} tên project, user={'có' if fullname else 'KHÔNG thấy'}")
PYEOF
fi

# Áp cặp thay thế lên snapshot: SUB + USER_* (gender chỉ trong section "User profile" của AGENTS.md).
python3 - "$LOCAL_ENV" "$KIT_DIR/home" <<'PYEOF'
import os, re, sys

envf, root = sys.argv[1], sys.argv[2]
pairs, u_full, u_gender, u_addr = [], "", "", ""
for ln in open(envf, encoding="utf-8"):
    ln = ln.rstrip("\n")
    if not ln or ln.startswith("#"):
        continue
    parts = ln.split("|")
    if parts[0] == "SUB" and len(parts) == 3 and parts[1]:
        pairs.append((parts[1], parts[2]))
    elif parts[0] == "USER_FULLNAME" and len(parts) == 2:
        u_full = parts[1]
    elif parts[0] == "USER_GENDER" and len(parts) == 2:
        u_gender = parts[1]
    elif parts[0] == "USER_ADDRESS" and len(parts) == 2:
        u_addr = parts[1]
if u_full:
    pairs.append((u_full, "__USER_NAME__"))
if u_addr:
    pairs.append((u_addr, "__USER_ADDRESS__"))
pairs.sort(key=lambda p: -len(p[0]))  # dài trước ngắn sau

changed = 0
for dp, dn, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        try:
            txt = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        orig = txt
        for frm, to in pairs:
            if "/" in frm or " " in frm:
                txt = txt.replace(frm, to)
            else:
                # tên trần: chỉ thay khi đứng độc lập — không đụng identifier dài hơn chứa nó
                txt = re.sub(r"(?<![A-Za-z0-9_])" + re.escape(frm) + r"(?![A-Za-z0-9_])",
                             lambda _: to, txt)
        # gender chỉ thay trong section User profile của AGENTS.md (tránh đụng chữ thường)
        if u_gender and f == "AGENTS.md" and u_gender in txt:
            sec = re.search(r"(?ms)^(## User profile\n.*?)(?=^## |\Z)", txt)
            if sec:
                txt = txt[:sec.start(1)] + sec.group(1).replace(u_gender, "__USER_GENDER__") + txt[sec.end(1):]
        if txt != orig:
            open(p, "w", encoding="utf-8").write(txt)
            changed += 1
print(f"    ẩn danh {changed} file ({len(pairs)} cặp thay thế)")
PYEOF

# Strip dòng email/identity bên thứ ba trong skill claude-design (xoá dòng có email + chữ commit/author/identity).
python3 - "$SNAP_OPENCODE/skills/claude-design/AGENTS.md" <<'PYEOF'
import re, sys
p = sys.argv[1]
try:
    txt = open(p, encoding="utf-8").read()
except OSError:
    sys.exit(0)
out = [ln for ln in txt.splitlines()
       if not (re.search(r"[\w.+-]+@[\w-]+\.[\w.]+", ln) and re.search(r"(?i)commit|author|identity", ln))]
if out != txt.splitlines():
    open(p, "w", encoding="utf-8").write("\n".join(out) + "\n")
    print(f"    đã xoá {len(txt.splitlines()) - len(out)} dòng email/identity trong claude-design/AGENTS.md")
PYEOF

# synced/<uuid> -> synced/claude-account (UUID là account identifier; không gì tham chiếu tên này).
SYNCED_DIR="$SNAP_CLAUDE_SKILLS/synced"
if [ -d "$SYNCED_DIR" ]; then
  for sub in "$SYNCED_DIR"/*/; do
    [ -d "$sub" ] || continue
    base="$(basename "$sub")"
    case "$base" in
      claude-account) ;;
      *[0-9a-f-]?????????????????????????*)
        mv "$sub" "$SYNCED_DIR/claude-account"
        echo "    synced/$base -> synced/claude-account" ;;
    esac
  done
fi

echo "==> 5/8 Làm sạch opencode.json"
# opencode.json: nếu mcp.finder.headers.Authorization còn là "Bearer <token>" literal thì đổi thành
# tham chiếu file secret. Nếu đã là {file:...} thì giữ nguyên.
python3 - "$SNAP_OPENCODE/opencode.json" <<'PYEOF'
import json, sys
path = sys.argv[1]
with open(path) as f:
    d = json.load(f)
try:
    headers = d["mcp"]["finder"]["headers"]
except KeyError:
    headers = None
if headers is not None:
    auth = headers.get("Authorization", "")
    if "{file:" not in auth:
        headers["Authorization"] = "Bearer {file:~/.secrets/opencode/finder-token}"
        print("    opencode.json: Authorization literal -> {file:~/.secrets/opencode/finder-token}")
    else:
        print("    opencode.json: Authorization đã là {file:...} (giữ nguyên)")
with open(path, "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
    f.write("\n")
PYEOF

echo "==> 6/8 Templates (finder settings + LaunchAgent)"
# templates/finder-settings.json: che mọi giá trị có key/token/secret trong tên (đệ quy),
# bỏ state nặng/gắn máy (repos, repo_generations, số dư credit, mốc kết nối...).
mkdir -p "$KIT_DIR/templates"
python3 - "$FINDER_SETTINGS" "$KIT_DIR/templates/finder-settings.json" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    d = json.load(f)

DROP_TOP = {"repos", "denied_repos", "repo_generations", "purchased_plans"}
DROP_GATEWAY = {"connected_at", "last_validated_at", "status", "credit_balance",
                "credits_total", "credit_expires_at", "plan_id", "models"}

def scrub(obj):
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            lk = k.lower()
            if any(t in lk for t in ("key", "token", "secret")):
                out[k] = ["<REDACTED>"] if isinstance(v, list) else "<REDACTED>"
            else:
                out[k] = scrub(v)
        return out
    if isinstance(obj, list):
        return [scrub(v) for v in obj]
    return obj

clean = {k: scrub(v) for k, v in d.items() if k not in DROP_TOP}
if isinstance(clean.get("gateway"), dict):
    clean["gateway"] = {k: v for k, v in clean["gateway"].items() if k not in DROP_GATEWAY}

with open(dst, "w") as f:
    json.dump(clean, f, indent=2, ensure_ascii=False)
    f.write("\n")
print(f"    templates/finder-settings.json: bỏ {sorted(DROP_TOP)}, giữ {len(clean)} key gốc")
PYEOF

# LaunchAgent plist -> templates/local.tavily-key-pool.plist: label trung lập + __HOME__.
PLIST_SRC="$(ls "$HOME"/Library/LaunchAgents/*.tavily-key-pool.plist 2>/dev/null | head -1 || true)"
rm -f "$KIT_DIR"/templates/com.*.tavily-key-pool.plist
if [ -n "$PLIST_SRC" ] && [ -f "$PLIST_SRC" ]; then
  HOME_REAL="$HOME" python3 - "$PLIST_SRC" "$KIT_DIR/templates/local.tavily-key-pool.plist" <<'PYEOF'
import os, re, sys
src, dst = sys.argv[1], sys.argv[2]
txt = open(src, encoding="utf-8").read()
txt = re.sub(r"(<key>Label</key>\s*<string>)[^<]+(</string>)",
             r"\g<1>local.tavily-key-pool\g<2>", txt)
txt = txt.replace(os.environ["HOME_REAL"], "__HOME__")
open(dst, "w", encoding="utf-8").write(txt)
print("    templates/local.tavily-key-pool.plist: ok (label local.tavily-key-pool)")
PYEOF
else
  echo "    cảnh báo: không thấy plist tavily-key-pool trong ~/Library/LaunchAgents — giữ template cũ (nếu có)"
fi

echo "==> 7/8 Quét secret trong repo"
KIT_DIR="$KIT_DIR" FINDER_SETTINGS="$FINDER_SETTINGS" python3 - "${ALLOWLIST[@]+"${ALLOWLIST[@]}"}" <<'PYEOF'
import json, os, re, sys

kit = os.environ["KIT_DIR"]
allow = set(sys.argv[1:])
hits, allowed_hits = [], []

patterns = [
    ("openai-ish",   re.compile(r"sk-[A-Za-z0-9]{20,}")),
    ("tavily",       re.compile(r"tvly-[A-Za-z0-9]{10,}")),
    ("github-pat",   re.compile(r"ghp_[A-Za-z0-9]{20,}")),
    ("github-oauth", re.compile(r"gho_[A-Za-z0-9]{20,}")),
    ("github-fine",  re.compile(r"github_pat_[A-Za-z0-9_]{20,}")),
    ("aws-akid",     re.compile(r"AKIA[0-9A-Z]{16}")),
    ("bearer",       re.compile(r"Bearer [A-Za-z0-9._-]{20,}")),
    ("voyage",       re.compile(r"pa-[A-Za-z0-9_-]{20,}")),
    ("pem-privkey",  re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("google-api",   re.compile(r"AIza[0-9A-Za-z_-]{35}")),
    ("slack",        re.compile(r"xox[abpr]-[A-Za-z0-9-]{10,}")),
    ("npm-token",    re.compile(r"npm_[A-Za-z0-9]{36}")),
]

def mask(s):
    s = s.strip()
    return s if len(s) <= 8 else s[:6] + "..." + s[-2:]

# Secret exact-match: nội dung mọi file trong ~/.secrets/opencode, ~/.finder/server.token,
# mọi giá trị string có key/token/secret trong tên của ~/.finder/settings.json (đệ quy),
# và giá trị dạng key trong config.yaml của tavily-key-pool. Không in giá trị — chỉ mask.
secrets = []
def add_secret(raw, origin):
    v = raw.strip()
    if len(v) >= 6:
        secrets.append((v, origin))
sec_dir = os.path.expanduser("~/.secrets/opencode")
if os.path.isdir(sec_dir):
    for name in sorted(os.listdir(sec_dir)):
        p = os.path.join(sec_dir, name)
        if os.path.isfile(p):
            try:
                with open(p, "rb") as f:
                    add_secret(f.read().decode("utf-8", "ignore"), f"~/.secrets/opencode/{name}")
            except OSError:
                pass
tok = os.path.expanduser("~/.finder/server.token")
if os.path.isfile(tok):
    with open(tok, "rb") as f:
        add_secret(f.read().decode("utf-8", "ignore"), "~/.finder/server.token")
fs_path = os.environ.get("FINDER_SETTINGS", "")
if fs_path and os.path.isfile(fs_path):
    try:
        fs = json.load(open(fs_path))
        def harvest(o, path=""):
            if isinstance(o, dict):
                for k, v in o.items():
                    p = f"{path}.{k}" if path else k
                    if any(t in k.lower() for t in ("key", "token", "secret")):
                        if isinstance(v, str):
                            add_secret(v, f"finder:{p}")
                        elif isinstance(v, list):
                            for it in v:
                                if isinstance(it, str):
                                    add_secret(it, f"finder:{p}[]")
                    else:
                        harvest(v, p)
            elif isinstance(o, list):
                for it in o:
                    harvest(it, path + "[]")
        harvest(fs)
    except (json.JSONDecodeError, OSError):
        pass
tavily_cfg = os.path.expanduser("~/.config/opencode/tools/tavily-key-pool/config.yaml")
if os.path.isfile(tavily_cfg):
    with open(tavily_cfg, "rb") as f:
        txt = f.read().decode("utf-8", "ignore")
    for m in re.findall(r"tvly-[A-Za-z0-9_-]+", txt):
        add_secret(m, "tavily config.yaml")
    for m in re.findall(r":\s*[\"']?([A-Za-z0-9._-]{24,})[\"']?\s*$", txt, re.M):
        add_secret(m, "tavily config.yaml")

# Exact-match có "boundary": ký tự liền trước/sau không được là chữ-số —
# tránh bắt nhầm secret ngắn nằm trong một token dài hơn (vd username trong URL repo).
secret_res = [(re.compile(r"(?<![A-Za-z0-9])" + re.escape(v) + r"(?![A-Za-z0-9])"), v, origin)
              for v, origin in secrets]

for root, dirs, files in os.walk(kit):
    dirs[:] = [d for d in dirs if d != ".git"]
    for fn in files:
        p = os.path.join(root, fn)
        rel = os.path.relpath(p, kit)
        try:
            with open(p, "rb") as f:
                raw = f.read()
        except OSError:
            continue
        text = raw.decode("utf-8", errors="ignore")  # không bỏ sót file lỗi encoding
        for lineno, line in enumerate(text.splitlines(), 1):
            for pname, pat in patterns:
                for m in pat.finditer(line):
                    (allowed_hits if rel in allow else hits).append(
                        (rel, lineno, pname, mask(m.group(0))))
            for sre, sval, origin in secret_res:
                if sre.search(line):
                    (allowed_hits if rel in allow else hits).append(
                        (rel, lineno, f"exact:{origin}", mask(sval)))

for rel, lineno, pname, m in allowed_hits:
    print(f"    [allowlist] {rel}:{lineno} ({pname}): {m}")

if hits:
    print("    PHÁT HIỆN SECRET TRONG REPO:", file=sys.stderr)
    for rel, lineno, pname, m in hits:
        print(f"      {rel}:{lineno} ({pname}): {m}", file=sys.stderr)
    sys.exit(1)
print(f"    sạch — đã quét {len(patterns)} pattern + {len(secrets)} secret exact-match")
PYEOF

echo "==> 8/8 Tổng kết"
echo "    dung lượng repo: $(du -sh "$KIT_DIR" | cut -f1) (trong đó .git: $(du -sk "$KIT_DIR/.git" 2>/dev/null | cut -f1) KB)"
big=$(find "$KIT_DIR" -not -path '*/.git/*' -type f -size +50M 2>/dev/null)
if [ -n "$big" ]; then
  echo "    CẢNH BÁO: file >50MB:"; echo "$big" | sed 's/^/      /'
fi

if [ "$PUSH" -eq 1 ]; then
  git -C "$KIT_DIR" remote get-url origin >/dev/null 2>&1 || {
    echo "sync.sh: --push nhưng repo chưa có remote 'origin'" >&2; exit 1; }
  git -C "$KIT_DIR" add -A
  if git -C "$KIT_DIR" diff --cached --quiet; then
    echo "    không có thay đổi — bỏ qua commit"
  else
    git -C "$KIT_DIR" commit -m "sync: $(date +%Y-%m-%d)"
    git -C "$KIT_DIR" push
  fi
else
  echo "    xong (không push — dùng --push để commit & push)"
fi
