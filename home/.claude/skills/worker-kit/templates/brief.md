# Worker brief — PHASE_NAME

Repo: REPO_ABSOLUTE_PATH · Branch: BRANCH · Written by: Claude (planner) · Date: YYYY-MM-DD
Workspace: this file lives in `<WS>/briefs/`; shared decisions are in `<WS>/rulings.md`.

## Rules
- Scope (the ONLY files you may edit or create):
  - `path/a`
  - `path/b`
- Off-limits (already modified by the user, never touch): `path/x`, `path/y`
- No git commit/push/reset/clean/stash/checkout/restore. No directory deletes.
- Follow this brief literally. Never guess: if anything is ambiguous, missing, or contradicts the code or a check, log `- [?] T<n> — QUESTION: … | OPTIONS: … | EVIDENCE: …` and stop.
- Run ONLY the cluster named in the run prompt. Do not explore the repo; every file you need is named here.

## Context
**Goal**: WHAT_MUST_BE_TRUE_WHEN_DONE (1-2 sentences, observable).

**Why**: ROOT_CAUSE_OR_MOTIVATION with `file:line` evidence.

**Follow this existing pattern** (shape, naming, error handling):
```LANG
EXCERPT_OF_A_SIMILAR_IMPLEMENTATION_ALREADY_IN_THE_REPO (10-30 lines, with its path)
```

**Conventions that apply**: STATE_MGMT / DI / naming / l10n / logging rules from AGENTS.md that touch this change.

**Domain decisions** (currency, rounding, locale, units, copy text): DECIDED_VALUES — or "none".

**Callers / tests of every changed symbol** (planner: Finder `context`/`impact` + `rg -n "<name>\("`), each with what to do: `path:line` — WHAT_THEY_EXPECT → covered by T<n> / leave as is

**Do NOT**: APPROACHES_THAT_LOOK_RIGHT_BUT_ARE_WRONG_HERE.

## Rulings
Phase-specific decisions (shared ones are in `<WS>/rulings.md`). "none" at first.
- none

## Finder requests
none — the planner already resolved discovery; everything needed is in Context and the Edit blocks.
(Only when a gap is unavoidable: exact finder-kit §3 request with `workspace_full_path`, filters, and purpose.)

## T0 — Baseline
Measured by the script (`dispatch.sh --baseline "VERIFY_COMMAND"`); its line appears in the Worker log.

## C1 — CLUSTER_NAME (1-4 tasks that make one testable step)

### T1 — ONE_BOUNDED_CHANGE
**Edit** `REPO_RELATIVE_PATH`
```old
CURRENT_CODE_VERBATIM (unique in the file; include enough surrounding lines)
```
```new
NEW_CODE_COMPLETE (including docstring/comment/parameter-name updates)
```
**Edit** `test/REPO_RELATIVE_PATH`
```old
CURRENT_CODE_VERBATIM
```
```new
NEW_CODE_COMPLETE (the test for the new behavior)
```
**Verify**:
```bash
VERIFY_COMMAND (format + analyze/test of the touched files, one shell line)
```
**Done when**: OBSERVABLE_CONDITION

### T2 — ...

**Gate** (run by the script as `--check`; confirms the tasks, never defines new behavior):
```bash
GATE_TEST_COMMAND
```

## C2 — CLUSTER_NAME
...

## Self-review (optional; answered after the last cluster, with evidence)
1. Paste `git diff --stat`. Is every file in Scope?

## Worker log
<!-- One append per cluster: - [x] T1 — command → exit 0 | evidence -->
