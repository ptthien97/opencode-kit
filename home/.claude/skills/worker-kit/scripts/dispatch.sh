#!/usr/bin/env bash
# worker-kit v6: dispatch one brief (or one cluster of it) to the opencode
# `worker` agent, stream progress, measure it, and record it.
#
# Usage: dispatch.sh <brief.md> [--cwd REPO] [--cluster C<k>] [--check "<gate>"]
#          [--baseline "<cmd>"] [--resume SESSION] [--protect FILE]...
#          [--model provider/model] [--ledger PATH] [--start-timeout SEC]
#          [--idle-timeout SEC] [--max-minutes N] [--no-lint]
#
# Order: lint (sections, placeholders, Edit blocks of this cluster against the
# code) → require preflight → baseline T0 (measured once) → run the worker
# (watchdogs, 1 retry on a start hang, live STEP events) → tamper check → new
# questions → gate → review package → ledger row.
#
# Briefs in a shared workspace (<WS>/briefs/*.md, see ws.sh) also protect
# <WS>/rulings.md and <WS>/plan.md, log to <WS>/ledger.md, and write review
# packages to <WS>/reviews/.
#
# Events: LINT, PREFLIGHT, BASELINE, START, RUNNING, STEP, PROGRESS, RETRY,
# STALL, WORKER exit=, SESSION, TOKENS, ERROR, SUMMARY, CHANGED,
# BRIEF_TAMPERED, QUESTION, ASK, CHECK exit=, CHECKOUT, REVIEW, LEDGER, DONE,
# FAIL.
# Exit: 0 done · 2 usage · 3 lint · 4 questions · 5 no preflight · 6 plan
# edited · 124 start hang · 125 stall · else the gate's or the worker's code.
set -u

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }
BRIEF="${1:-}"
case "$BRIEF" in -h|--help) usage; exit 0 ;; esac
[ -n "$BRIEF" ] && [ -f "$BRIEF" ] || { echo "FAIL usage: dispatch.sh <brief.md> [opts] (--help)"; exit 2; }
shift
abs() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
BRIEF="$(abs "$BRIEF")"

CWD="$(pwd)"; MODEL="${WORKER_MODEL:-}"; CHECK=""; BASELINE=""; RESUME=""; CLUSTER=""
LEDGER=""; PROTECT=(); LINT=1; START_TIMEOUT=120; IDLE_TIMEOUT=600; MAX_MINUTES=90
while [ $# -gt 0 ]; do
  case "$1" in
    --cwd) CWD="$2"; shift 2 ;;
    --cluster) CLUSTER="$2"; shift 2 ;;
    --check) CHECK="$2"; shift 2 ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --resume) RESUME="$2"; shift 2 ;;
    --protect) [ -f "$2" ] || { echo "FAIL --protect file not found: $2"; exit 2; }
               PROTECT+=("$(abs "$2")"); shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --ledger) LEDGER="$2"; shift 2 ;;
    --start-timeout) START_TIMEOUT="$2"; shift 2 ;;
    --idle-timeout) IDLE_TIMEOUT="$2"; shift 2 ;;
    --max-minutes) MAX_MINUTES="$2"; shift 2 ;;
    --no-lint) LINT=0; shift ;;
    *) echo "FAIL unknown option $1"; exit 2 ;;
  esac
done
CWD="$(cd "$CWD" && pwd)"
LOG_DIR="${WORKER_LOG_DIR:-/tmp/worker-kit}"; mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)-$$"

# Shared workspace: <WS>/briefs/<brief>.md with <WS>/rulings.md beside briefs/.
WS=""
case "$BRIEF" in */briefs/*.md) d="$(dirname "$(dirname "$BRIEF")")"; [ -f "$d/rulings.md" ] && WS="$d" ;; esac
if [ -n "$WS" ]; then
  [ -n "$LEDGER" ] || LEDGER="$WS/ledger.md"
  REVIEW_DIR="$WS/reviews"
  for f in "$WS/rulings.md" "$WS/plan.md"; do [ -f "$f" ] && PROTECT+=("$f"); done
else
  [ -n "$LEDGER" ] || LEDGER="$(dirname "$BRIEF")/worker-ledger.md"
  REVIEW_DIR="$LOG_DIR/reviews"
fi
mkdir -p "$REVIEW_DIR"
LOGFILES=("$BRIEF" "${PROTECT[@]+"${PROTECT[@]}"}")

# ---- 1. Lint -----------------------------------------------------------------
BRIEF_PLACEHOLDERS='PHASE_NAME|REPO_ABSOLUTE_PATH|WHAT_MUST_BE_TRUE_WHEN_DONE|ROOT_CAUSE_OR_MOTIVATION|WHAT_TO_LEARN_THERE|EXCERPT_OF_A_SIMILAR|APPROACHES_THAT_LOOK_RIGHT|BEHAVIOR_IN_CODEBASE_TERMS|ONE_BOUNDED_CHANGE|CURRENT_CODE_VERBATIM|NEW_CODE_COMPLETE|OBSERVABLE_CONDITION|VERIFY_COMMAND|CLUSTER_NAME|GATE_TEST_COMMAND|RECON_TOPIC|RECON_PURPOSE|EVIDENCE_FILE_PATH|QUESTION_R1|QUESTION_R2|QUESTION_R3|DECIDED_VALUES|WHAT_THEY_EXPECT|REPO_RELATIVE_PATH'
ANSWER_PLACEHOLDERS='QUESTION_COPIED_FROM_THE_LOG|THE_DECISION_AND_WHY|ORIGINAL_BRIEF_PATH|EXTRA_TASK|PHASE_NAME'
if [ "$LINT" = 1 ] && [ -z "$RESUME" ]; then
  missing=""
  for pat in '^## Rules' '^## Context' '^## Rulings' '^## Finder requests' '^## T0' \
             '\*\*Verify\*\*' '\*\*Done when\*\*' '^## Worker log'; do
    grep -qE "$pat" "$BRIEF" || missing="$missing ${pat//\\/}"
  done
  left="$(grep -oE "$BRIEF_PLACEHOLDERS" "$BRIEF" | sort -u | tr '\n' ' ')"
  [ -n "$left" ] && missing="$missing placeholders:[ $left]"
  grep -qE '^## C[0-9]+' "$BRIEF" && [ -z "$CLUSTER" ] && missing="$missing --cluster(brief-has-clusters)"
  if [ -n "$missing" ]; then echo "LINT FAIL missing:$missing"; echo "FAIL brief incomplete"; exit 3; fi
  echo "LINT ok"
elif [ "$LINT" = 1 ]; then
  left="$(grep -oE "$ANSWER_PLACEHOLDERS" "$BRIEF" | sort -u | tr '\n' ' ')"
  if [ -n "$left" ]; then echo "LINT FAIL placeholders:[ $left]"; echo "FAIL answers brief incomplete"; exit 3; fi
  echo "LINT ok (resume)"
fi
if [ -n "$CLUSTER" ] && ! grep -qE "^## $CLUSTER( |$)" "$BRIEF"; then
  echo "FAIL cluster $CLUSTER not found in $BRIEF (pass the brief that defines it, also on --resume)"; exit 3
fi

# Edit blocks of this cluster (or of the whole brief) must match the code now:
# each `old` occurs exactly once; an empty `old` means a new file.
if [ "$LINT" = 1 ]; then
  EB="$(python3 -I - "$BRIEF" "$CWD" "$CLUSTER" <<'PY'
import os, re, sys
brief, root, cluster = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(brief, encoding="utf-8").read().split("\n## Worker log")[0]
if cluster:
    m = re.search(r"^## " + re.escape(cluster) + r"\b.*?(?=^## |\Z)", text, re.S | re.M)
    text = m.group(0) if m else ""
blocks = re.findall(r"\*\*Edit\*\* `([^`]+)`[^\n]*\n```old[^\n]*\n(.*?)```[ \t]*\n```new[^\n]*\n(.*?)```", text, re.S)
bad = []
for path, old, _new in blocks:
    full = os.path.join(root, path)
    if old.strip() == "":
        if os.path.exists(full):
            bad.append(f"{path}: empty old block means a new file, but the file exists")
        continue
    if not os.path.exists(full):
        bad.append(f"{path}: file not found")
        continue
    n = open(full, encoding="utf-8", errors="replace").read().count(old)
    if n != 1:
        bad.append(f"{path}: old block found {n} times (must be exactly 1)")
print(len(blocks))
for b in bad:
    print(b)
PY
)"
  nblocks="$(printf '%s\n' "$EB" | head -1)"; ebad="$(printf '%s\n' "$EB" | sed -n '2,$p' | tr '\n' ';')"
  if [ -n "$ebad" ]; then echo "LINT FAIL edit blocks: $ebad"; echo "FAIL brief does not match the code"; exit 3; fi
  [ "${nblocks:-0}" -gt 0 ] && echo "LINT edit-blocks ok $nblocks/$nblocks"
fi

# ---- 2. Preflight stamp --------------------------------------------------------
EFFECTIVE_MODEL="$MODEL"
[ -z "$EFFECTIVE_MODEL" ] && EFFECTIVE_MODEL="$(sed -n 's/^model:[[:space:]]*//p' "$HOME/.config/opencode/agents/worker.md" | head -1)"
pf="$LOG_DIR/preflight-ok-$(printf '%s' "${EFFECTIVE_MODEL%%#*}" | tr '/:' '__')"
max_age="${PREFLIGHT_MAX_AGE:-1800}"
if [ ! -f "$pf" ] || [ $(( $(date +%s) - $(cat "$pf") )) -gt "$max_age" ]; then
  echo "FAIL no preflight for $EFFECTIVE_MODEL in the last $((max_age / 60))m: run preflight.sh --model $EFFECTIVE_MODEL --cwd $CWD, confirm with the user, then dispatch"
  exit 5
fi
echo "PREFLIGHT ok model=$EFFECTIVE_MODEL ($(( ($(date +%s) - $(cat "$pf")) / 60 ))m ago)"

# ---- 3. Baseline (T0), measured once by the script ---------------------------------
if [ -n "$BASELINE" ] && ! grep -q '^- \[x\] T0 (script)' "$BRIEF"; then
  bout="$REVIEW_DIR/$STAMP-baseline.txt"
  ( cd "$CWD" && bash -c "$BASELINE" ) > "$bout" 2>&1; brc=$?
  fails="$(grep -E '\[E\]|FAILED|^FAIL|Error:|AssertionError' "$bout" | head -5 | tr '\n' ';' | cut -c1-300)"
  printf -- '- [x] T0 (script) — `%s` → exit %s | %s (full output: %s)\n' \
    "$BASELINE" "$brc" "${fails:-$(tail -1 "$bout" | cut -c1-120)}" "$bout" >> "$BRIEF"
  echo "BASELINE exit=$brc ${fails:+failing: $fails}"
fi

# Plain ASCII one-line prompt: long or special-character prompts hung runs before.
RULE="Follow the brief exactly. Never use the question tool; if anything is unclear or contradicts the code or a check, log a [?] question in the brief and stop."
if [ -n "$CLUSTER" ]; then
  PROMPT="Read the file $BRIEF. Execute ONLY cluster $CLUSTER, append its log lines in one edit, then stop. $RULE"
else
  PROMPT="Read the file $BRIEF and execute it exactly as written. $RULE"
fi
[ -n "$WS" ] && PROMPT="$PROMPT Shared rulings: $WS/rulings.md."

# ---- 4. Snapshots before the run --------------------------------------------------
log_lines() { cat "${LOGFILES[@]}" 2>/dev/null | grep -E "^- \\[$1\\] " || true; }
plan_hash() { for f in "${LOGFILES[@]}"; do printf '%s ' "$f"; sed '/^## Worker log/,$d' "$f" | shasum | cut -d' ' -f1; done; }
snapshot() {
  ( cd "$CWD" && git status --porcelain=v1 -uall 2>/dev/null | cut -c4- | sed 's/.* -> //' |
    while IFS= read -r p; do printf '%s\t%s\n' "$p" "$(git hash-object -- "$p" 2>/dev/null || echo gone)"; done ) | sort
}
BEFORE="$(snapshot)"; PLAN_BEFORE="$(plan_hash)"; PRE_Q="$(log_lines '\?')"

# ---- 5. Run with watchdogs; live STEP events from the JSON stream ----------------------
emit_new() { [ "$1" != "$2" ] && comm -13 <(printf '%s\n' "$1") <(printf '%s\n' "$2") | grep -v '^$' | sed 's/^/PROGRESS /'; }
steps_from() { # $1 jsonl, $2 byte offset → STEP lines, then "OFFSET <n>"
  python3 -I - "$1" "$2" <<'PY'
import json, os, sys
path, off = sys.argv[1], int(sys.argv[2])
with open(path, "rb") as fh:
    fh.seek(off)
    data = fh.read()
end = data.rfind(b"\n") + 1
for raw in data[:end].splitlines():
    try:
        ev = json.loads(raw)
    except ValueError:
        continue
    p = ev.get("part") or {}
    st = p.get("state") or {}
    if p.get("type") == "tool" and st.get("status") in ("completed", "error"):
        i = st.get("input") or {}
        f = i.get("path") or i.get("filePath")
        tgt = os.path.basename(f) if f else " ".join(str(i.get("command") or i.get("code") or "").split())[:90]
        print(f"STEP {p.get('tool')} {tgt}" + (" (error)" if st.get("status") == "error" else ""))
print(f"OFFSET {off + end}")
PY
}
run_once() { # $1 attempt; sets RC and LAST_LOG
  local jsonl="$LOG_DIR/$STAMP-try$1.jsonl" args=(run --standalone --auto --format json --agent worker)
  [ -n "$MODEL" ] && args+=(-m "$MODEL")
  [ -n "$RESUME" ] && args+=(--session "$RESUME")
  LAST_LOG="$jsonl"
  ( cd "$CWD" && exec opencode "${args[@]}" "$PROMPT" ) >"$jsonl" 2>&1 &
  local pid=$! started=0 waited=0 idle=0 last=-1 seen cur size tick=2 off=0 out
  seen="$(log_lines '.')"
  echo "START attempt=$1 pid=$pid log=$jsonl"
  while kill -0 "$pid" 2>/dev/null; do
    sleep "$tick"; waited=$((waited + tick))
    size=$(wc -c <"$jsonl" | tr -d ' ')
    if [ "$started" = 0 ]; then
      if [ "$size" -gt 0 ]; then started=1; echo "RUNNING after ${waited}s"
      elif [ "$waited" -ge "$START_TIMEOUT" ]; then
        kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
        echo "RETRY no output after ${START_TIMEOUT}s"; RC=124; return
      fi
    fi
    if [ "$size" -gt "$off" ]; then
      out="$(steps_from "$jsonl" "$off")"; off="$(printf '%s\n' "$out" | sed -n 's/^OFFSET //p')"
      printf '%s\n' "$out" | grep '^STEP' || true
    fi
    cur="$(log_lines '.')"; emit_new "$seen" "$cur"; seen="$cur"
    if [ "$size" = "$last" ]; then idle=$((idle + tick)); else idle=0; last=$size; fi
    if [ "$idle" -ge "$IDLE_TIMEOUT" ] || [ "$waited" -ge $((MAX_MINUTES * 60)) ]; then
      kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
      echo "STALL killed after ${idle}s without events (limit ${IDLE_TIMEOUT}s) or ${MAX_MINUTES}m total"; RC=125; return
    fi
  done
  wait "$pid"; RC=$?
  out="$(steps_from "$jsonl" "$off")"; printf '%s\n' "$out" | grep '^STEP' || true
  cur="$(log_lines '.')"; emit_new "$seen" "$cur"
}
RC=1; LAST_LOG=""
run_once 1
[ "$RC" = 124 ] && run_once 2
echo "WORKER exit=$RC"

# ---- 6. Session, steps, tokens, errors, final message -----------------------------------
INFO="$(python3 -I - "$LAST_LOG" <<'PY'
import json, sys
session, cost, tin, tcache, tout, steps, tools, text, errors = None, 0.0, 0, 0, 0, 0, 0, "", []
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        ev = json.loads(line)
    except ValueError:
        continue
    session = session or ev.get("sessionID")
    part = ev.get("part") or {}
    if ev.get("type") == "error":
        errors.append(str(ev.get("error") or ev)[:200])
    if part.get("type") == "text" and part.get("text"):
        text = part["text"]
    if part.get("type") == "tool":
        tools += 1
    if part.get("type") == "step-finish":
        steps += 1
        cost += float(part.get("cost") or 0)
        tok = part.get("tokens") or {}
        tin += int(tok.get("input") or 0)
        tout += int(tok.get("output") or 0)
        tcache += int((tok.get("cache") or {}).get("read") or 0)
print(f"SESSION {session or 'none'}")
print(f"TOKENS steps={steps} tools={tools} in={tin} cached={tcache} out={tout} cost=${cost:.4f}")
for e in errors[-3:]:
    print("ERROR " + e)
for row in text.strip("`\n ").splitlines()[:14]:
    if row.strip():
        print("SUMMARY " + row.strip()[:300])
PY
)"
printf '%s\n' "$INFO"
SESSION_ID="$(printf '%s\n' "$INFO" | sed -n 's/^SESSION //p')"
TOKENS="$(printf '%s\n' "$INFO" | sed -n 's/^TOKENS //p')"

AFTER="$(snapshot)"
CHANGED_FILES="$(comm -13 <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") | cut -f1 |
  while IFS= read -r p; do
    full="$CWD/$p"; skip=0
    for f in "${LOGFILES[@]}" "$LEDGER"; do [ "$full" = "$f" ] && skip=1; done
    case "$p" in */__pycache__/*|__pycache__/*|*.pyc|.dart_tool/*|*/.dart_tool/*|build/*|*/build/*) skip=1 ;; esac
    [ "$skip" = 0 ] && printf '%s ' "$p"
  done)"
echo "CHANGED ${CHANGED_FILES:-none}"

# ---- 7. Ledger and review package (written by the script, never the worker) ----------------
ledger() { # $1 result, $2 gate exit
  local lock="$LEDGER.lock" i=0
  while ! mkdir "$lock" 2>/dev/null && [ "$i" -lt 50 ]; do sleep 0.2; i=$((i + 1)); done
  if [ ! -f "$LEDGER" ]; then
    printf '%s\n' "# Worker ledger" "" \
      "| Time | Brief | Cluster | Runner / model | Session | Worker | Gate | Result | Changed files | Steps / tokens |" \
      "|---|---|---|---|---|---|---|---|---|---|" > "$LEDGER"
  fi
  printf '| %s | %s | %s | opencode worker / %s | %s | %s | %s | %s | %s | %s |\n' \
    "$(date '+%Y-%m-%d %H:%M')" "$(basename "$BRIEF")" "${CLUSTER:-all}${RESUME:+ (resume)}" \
    "$EFFECTIVE_MODEL" "${SESSION_ID:-none}" "$RC" "$2" "$1" "${CHANGED_FILES:-none}" "${TOKENS:-}" >> "$LEDGER"
  rmdir "$lock" 2>/dev/null
  echo "LEDGER $LEDGER"
}
review() { # $1 result, $2 gate exit, $3 gate output
  local f="$REVIEW_DIR/$STAMP-$(basename "$BRIEF" .md)-${CLUSTER:-all}.md" p
  {
    echo "# Review package — $(basename "$BRIEF") ${CLUSTER:-all} ($1)"
    echo
    echo "- Model: $EFFECTIVE_MODEL · session ${SESSION_ID:-none} · $TOKENS"
    echo "- Gate: \`${CHECK:-none}\` → exit $2"
    [ -n "$3" ] && { echo '```'; printf '%s\n' "$3" | tail -15; echo '```'; }
    echo "- Changed: ${CHANGED_FILES:-none}"
    for p in $CHANGED_FILES; do
      echo; echo "## $p"; echo '```diff'
      ( cd "$CWD" && if git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then git diff HEAD -- "$p"; else git diff --no-index -- /dev/null "$p"; fi ) 2>/dev/null | head -150
      echo '```'
    done
  } > "$f"
  echo "REVIEW $f"
}

# ---- 8. Verdicts ---------------------------------------------------------------------
if [ "$(plan_hash)" != "$PLAN_BEFORE" ]; then
  echo "BRIEF_TAMPERED plan part (above '## Worker log') changed in: $(diff <(printf '%s\n' "$PLAN_BEFORE") <(plan_hash) | sed -n 's/^> \([^ ]*\) .*/\1/p' | tr '\n' ' ')"
  ledger "BRIEF_TAMPERED" "skipped"; echo "FAIL plan edited by the worker log=$LAST_LOG"; exit 6
fi

# A new open question: a new "[?]" line in the QUESTION format, not re-marked as resolved.
NEW_Q="$(comm -13 <(printf '%s\n' "$PRE_Q") <(printf '%s\n' "$(log_lines '\?')") | grep 'QUESTION:' | grep -vi 'resolved' || true)"
if [ -n "$NEW_Q" ]; then
  printf '%s\n' "$NEW_Q" | sed 's/^/QUESTION /'
  echo "ASK answer, then: dispatch.sh <answers.md> --cwd $CWD --resume ${SESSION_ID:-<SESSION>} --protect $BRIEF --check \"<gate>\""
  review "ASK" "skipped" ""
  ledger "ASK" "skipped"; exit 4
fi

GATE="-"; gout=""
if [ -n "$CHECK" ]; then
  gout="$(cd "$CWD" && bash -c "$CHECK" 2>&1)"; GATE=$?
  echo "CHECK exit=$GATE cmd=$CHECK"
  [ -n "$gout" ] && printf '%s\n' "$gout" | tail -15 | sed 's/^/CHECKOUT /'
fi
if [ "$GATE" != "-" ] && [ "$GATE" != 0 ]; then RESULT="GATE_FAIL"
elif [ "$RC" = 0 ]; then RESULT="DONE"
else RESULT="WORKER_FAIL"; fi
review "$RESULT" "$GATE" "$gout"
ledger "$RESULT" "$GATE"
case "$RESULT" in
  DONE) echo "DONE log=$LAST_LOG"; exit 0 ;;
  GATE_FAIL) echo "FAIL gate exit=$GATE log=$LAST_LOG"; exit "$GATE" ;;
  *) echo "FAIL worker exit=$RC log=$LAST_LOG"; exit "$RC" ;;
esac
