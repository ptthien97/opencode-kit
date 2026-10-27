#!/usr/bin/env bash
# worker-kit v6 shared workspace: one persistent folder per repo + topic that
# Claude writes (plan, rulings, briefs, evidence) and workers read. Scripts add
# the ledger and review packages. It survives context compaction and is shared
# by every worker, including parallel ones in separate git worktrees.
#
# Usage: ws.sh init --repo <repo path> --topic <slug>   → creates it, prints WS=<path>
#        ws.sh path --repo <repo path> --topic <slug>   → prints the path
#        ws.sh status --repo <repo path> --topic <slug> → compact state for a fresh session
#        ws.sh list                                     → all workspaces
#
# Layout: <WS>/plan.md  rulings.md  ledger.md  briefs/  evidence/  reviews/
set -u
ROOT="${WORKER_KIT_HOME:-$HOME/.worker-kit}/ws"
KIT="$(cd "$(dirname "$0")/.." && pwd)"
cmd="${1:-}"; shift || true
REPO=""; TOPIC=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    --topic) TOPIC="$2"; shift 2 ;;
    *) echo "FAIL unknown option $1"; exit 2 ;;
  esac
done
ws_path() {
  [ -n "$REPO" ] && [ -n "$TOPIC" ] || { echo "FAIL --repo and --topic are required"; exit 2; }
  local name; name="$(basename "$(cd "$REPO" && pwd)")"
  printf '%s/%s/%s\n' "$ROOT" "$name" "$(printf '%s' "$TOPIC" | tr ' /' '--')"
}
case "$cmd" in
  init)
    WS="$(ws_path)"; mkdir -p "$WS/briefs" "$WS/evidence" "$WS/reviews"
    [ -f "$WS/plan.md" ] || cp "$KIT/templates/phase-plan.md" "$WS/plan.md"
    [ -f "$WS/rulings.md" ] || printf '%s\n' "# Rulings — $TOPIC" "" \
      "Decisions that apply to every phase and cluster. Only Claude writes here;" \
      "workers read it before every task. Format: R<n> (who, date): decision." "" "- none" > "$WS/rulings.md"
    [ -f "$WS/repo.txt" ] || (cd "$REPO" && pwd) > "$WS/repo.txt"
    echo "WS=$WS" ;;
  path) ws_path ;;
  status)
    # Compact state for a fresh Claude session: read this instead of the old
    # conversation (keeps every Claude turn small).
    WS="$(ws_path)"; [ -d "$WS" ] || { echo "FAIL no workspace $WS"; exit 1; }
    echo "WS=$WS"; echo "REPO=$(cat "$WS/repo.txt" 2>/dev/null)"
    echo "== phases (plan.md)"; grep -E '^\| P[0-9]' "$WS/plan.md" 2>/dev/null | cut -c1-220 || echo "none"
    echo "== rulings"; grep -E '^- ' "$WS/rulings.md" 2>/dev/null | cut -c1-200
    echo "== last runs (ledger)"; grep -E '^\| [0-9]{4}-' "$WS/ledger.md" 2>/dev/null | tail -6 | cut -d'|' -f2-4,7-10 || echo "none"
    echo "== open questions"
    for b in "$WS"/briefs/*.md; do
      [ -f "$b" ] || continue
      q="$(grep -E '^- \[\?\] .*QUESTION:' "$b" | grep -vi resolved | tail -2 | cut -c1-200)"
      [ -n "$q" ] && printf '%s: %s\n' "$(basename "$b")" "$q"
    done
    echo "== latest review"; ls -t "$WS"/reviews/*.md 2>/dev/null | head -1 ;;
  list) find "$ROOT" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort ;;
  *) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
