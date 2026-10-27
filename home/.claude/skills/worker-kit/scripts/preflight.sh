#!/usr/bin/env bash
# Preflight the worker before any dispatch: tool, agent, model, a real reply,
# and (optionally) Finder access for the repo. Writes a stamp that
# dispatch.sh requires, so a task never starts on a worker that cannot run.
#
# Usage: preflight.sh [--model provider/model] [--cwd REPO] [--timeout SEC]
# Stdout: PREFLIGHT <check> ok|FAIL <detail> ... then READY or NOT_READY.
set -u

AGENT_FILE="$HOME/.config/opencode/agents/worker.md"
MODEL="${WORKER_MODEL:-}"
CWD=""
TIMEOUT=90
while [ $# -gt 0 ]; do
  case "$1" in
    --model) MODEL="$2"; shift 2 ;;
    --cwd) CWD="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "PREFLIGHT args FAIL unknown option $1"; echo "NOT_READY"; exit 2 ;;
  esac
done

fail() { echo "PREFLIGHT $1 FAIL $2"; echo "NOT_READY"; exit 1; }

command -v opencode >/dev/null || fail opencode "not on PATH"
echo "PREFLIGHT opencode ok $(opencode --version 2>/dev/null | head -1)"

[ -f "$AGENT_FILE" ] || fail agent "missing $AGENT_FILE"
AGENT_MODEL="$(sed -n 's/^model:[[:space:]]*//p' "$AGENT_FILE" | head -1)"
[ -z "$MODEL" ] && MODEL="$AGENT_MODEL"
[ -n "$MODEL" ] || fail model "no --model and no model: line in worker.md"
echo "PREFLIGHT agent ok worker (default model: ${AGENT_MODEL:-none})"

base="${MODEL%%#*}"
opencode models 2>/dev/null | grep -qxF "$base" || fail model "$base not in 'opencode models'"
echo "PREFLIGHT model ok $MODEL"

# A real round trip through the worker agent: catches quota limits, auth
# errors, and startup hangs before any task is handed over.
LOG_DIR="${WORKER_LOG_DIR:-/tmp/worker-kit}"; mkdir -p "$LOG_DIR"
out="$LOG_DIR/preflight-$(date +%s).jsonl"
start=$(date +%s)
( cd "${CWD:-/tmp}" && exec opencode run --standalone --format json --agent worker -m "$MODEL" \
    "Preflight. Reply with exactly: READY" ) >"$out" 2>&1 &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
  sleep 2
  if [ $(( $(date +%s) - start )) -ge "$TIMEOUT" ]; then
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    fail reply "no answer within ${TIMEOUT}s (startup hang or provider queue)"
  fi
done
wait "$pid"; rc=$?
secs=$(( $(date +%s) - start ))
err="$(grep -o '"type":"error"[^}]*}' "$out" | head -1 | grep -oE '"(type|message)":"[^"]*"' | tail -2 | tr '\n' ' ')"
[ -n "$err" ] && fail reply "$err"
grep -q 'READY' "$out" || fail reply "exit=$rc, no READY in reply (log $out)"
echo "PREFLIGHT reply ok READY in ${secs}s"

# Tool calling: a model can chat yet fail to call tools through a provider.
tout="$LOG_DIR/preflight-tool-$(date +%s).jsonl"
start=$(date +%s)
( cd "${CWD:-/tmp}" && exec opencode run --standalone --auto --format json --agent worker -m "$MODEL" \
    "Preflight tool check. Use the shell tool to run: echo PF_TOOL_\$((40+2)) . Then reply with the command output only." ) >"$tout" 2>&1 &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
  sleep 2
  if [ $(( $(date +%s) - start )) -ge "$TIMEOUT" ]; then
    kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
    fail tools "no tool round trip within ${TIMEOUT}s"
  fi
done
grep -q 'PF_TOOL_42' "$tout" || fail tools "shell tool did not run (log $tout)"
echo "PREFLIGHT tools ok shell round trip in $(( $(date +%s) - start ))s"

# Finder reachability for the repo the task will run in (warning only: the
# worker falls back to rg/read when Finder is unavailable).
if [ -n "$CWD" ]; then
  if curl -s -m 3 -o /dev/null http://127.0.0.1:3636/ 2>/dev/null; then
    echo "PREFLIGHT finder ok server reachable"
  else
    echo "PREFLIGHT finder WARN server not reachable; worker will use rg/read"
  fi
fi

stamp="$LOG_DIR/preflight-ok-$(printf '%s' "$base" | tr '/:' '__')"
date +%s > "$stamp"
echo "READY model=$MODEL stamp=$stamp"
