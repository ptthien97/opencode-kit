# Worker brief — RECON_TOPIC (recon, no source edits)

Repo: REPO_ABSOLUTE_PATH · Written by: Claude (planner) · Date: YYYY-MM-DD

## Rules
- Scope: create `EVIDENCE_FILE_PATH` only. Edit no other file.
- No git commit/push/reset/clean/stash/checkout/restore.
- Follow this brief literally. Never guess: if a request returns nothing useful or the code differs from what is described, write that as a gap; log `- [?]` only if you cannot continue.

## Context
**Goal**: an evidence pack that lets the planner write a detailed plan without reading these files itself.
**Why**: RECON_PURPOSE

## Rulings
- none

## Finder requests
Run each exactly as written (`workspace_full_path`: REPO_ABSOLUTE_PATH). Budget: 2 extra calls per request to fill a named gap.
- R1 `finder` — "BEHAVIOR_IN_CODEBASE_TERMS. Likely identifiers: ID1, ID2, ID3. Production code." · `filter_path`: "lib/" · `filter_lang`: ["dart"] · must answer: QUESTION_R1
- R2 `context` — selector `{"symbol_file": {"symbol": "SYMBOL", "file": "repo/relative/path.dart"}}` · must answer: QUESTION_R2
- R3 `impact` — same selector shape, `direction`: "upstream" · must answer: QUESTION_R3
- R4 shell — `rg -n "SYMBOL\(" lib test` · must answer: the exhaustive caller list; compare with R2/R3 (the Finder graph misses Dart static calls) and list every difference

## T0 — Baseline
```bash
test -e EVIDENCE_FILE_PATH; echo "exists=$?"
```

## T1 — Write the evidence pack · ~10 min
**File**: `EVIDENCE_FILE_PATH` (new)
**Do**: for each request, a section:
```markdown
## R1 — <request>
Answer: <1-3 sentences answering "must answer">
Evidence:
- `path:line-line` — <what it shows>
  ```dart
  <verbatim excerpt, max 15 lines, read from the current file>
  ```
Callers / impact: <list with path:line, from context/impact>
Gaps: <what is still unknown, or none>
```
Read every cited range from the current file before quoting it (Finder results are leads). Label any answer that rests only on the Finder graph as "Finder graph only".
**Verify**:
```bash
grep -c '^## R' EVIDENCE_FILE_PATH
```
**Done when**: one section per request, each with Answer, Evidence, Gaps.

## Self-review
1. Which answers rest only on Finder records you did not read in source? List them.

## Worker log
