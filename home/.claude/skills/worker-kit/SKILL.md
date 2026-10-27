---
name: worker-kit
description: "Planner/worker split for implementation: Claude (Opus) decides and writes a detailed phase plan and briefs (with finder-kit Finder requests); a cheaper headless worker (opencode `worker` agent, default vua/deepseek-v4.1-flash) executes them cluster by cluster with test gates; scripts measure gates, track every run in a ledger, and block bad dispatches; Claude reviews and grades each run and feeds lessons into the next plan. Use when the user asks to plan for or hand work to the worker ('giao worker', 'cho worker làm', 'dispatch', 'opencode làm'), to change the worker model ('đổi model worker'), to run the kit self-test, or invokes /worker-kit."
---
<!-- worker-kit-v6.1 -->

# Worker Kit

## Principles

1. **Claude decides, the worker executes.** Claude (Opus) spends tokens only on
   thinking: decisions, the detailed plan, briefs with exact code, answers, and
   the final grade. Everything mechanical goes to the worker: recon, baseline,
   edits, format/analyze/tests, gates, review packages.
2. **The plan is fixed.** The worker follows the brief literally and never edits
   it (it only appends below `## Worker log`). `dispatch.sh` hashes the plan part
   and fails the run on any edit (`BRIEF_TAMPERED`, exit 6).
3. **Never guess.** Anything ambiguous, contradictory, or missing comes back as a
   `[?]` question; the run stops (`ASK`, exit 4) and Claude answers.
4. **Trust measurements, not reports.** The script runs each gate (`--check`),
   attributes changed files, and writes the ledger. Claude reads those; it does
   not re-run what the script measured.
5. **The user steers.** Plan → user approves → preflight → user confirms runner
   and model → run. Never dispatch without that confirmation.
6. **Small steps with gates.** Phases split into clusters of 1-4 tasks; each
   cluster ends in a test gate; a red gate never moves on.
7. **Everything is traceable.** Ledger row per run (model, session, cluster,
   result, files); "Done by" per phase; Rulings carried forward.
8. **Every run teaches the next plan.** Opus grades each run and records the
   root cause in `lessons.md`, which is read before every plan.
9. **Tests are real.** The kit and its changes are verified only with real
   model runs (`selftest.sh`), never with fakes.
10. **One shared workspace.** `~/.worker-kit/ws/<repo>/<topic>/` holds the
    plan, rulings, briefs, evidence, reviews, and ledger. Claude writes it,
    workers read it, scripts append to it; nothing is lost to compaction.
11. **Precise briefs, few steps.** Every worker tool call re-sends ~7k tokens of
    context. Briefs carry exact Edit blocks (`old` → `new`) that the script
    checks against the code before dispatch, so the worker never searches.
12. **Small Claude turns.** Claude's cost is (conversation size) × (number of
    turns), not the work: in a long session every turn re-reads ~600k tokens.
    So: one fresh session per phase, bootstrapped from `ws.sh status`; one
    wake-up per cluster (background run, read only the result lines); never
    re-read code the review package already shows.

## Files

| Path | Purpose |
|---|---|
| `SKILL.md` (this) | The workflow |
| `lessons.md` | Graded lessons from real runs. Read before every plan; append after every retro |
| `templates/recon.md` | Worker gathers Finder evidence for planning (no source edits) |
| `templates/phase-plan.md` | Phase table: outcome, clusters → gates, exclusive files, deps, parallel group, runner, Done by, status |
| `templates/brief.md` | One brief per phase, clusters inside, gates, rulings, Finder requests |
| `templates/answers.md` | Answers to `[?]` questions and extra tasks, sent with `--resume` |
| `scripts/ws.sh` | `init`/`path`/`status`/`list` the shared workspace; `status` is the ~400-token bootstrap for a fresh session |
| `FLOW.md` | The whole flow as a diagram |
| `scripts/preflight.sh` | Proves the worker runs (model, quota, reply, tool call, Finder); writes the stamp dispatch requires |
| `scripts/dispatch.sh` | Lint brief + Edit blocks → require preflight → baseline → run one cluster (live STEP events) → tamper check → questions → gate → review package → ledger |
| `scripts/selftest.sh` | Real end-to-end test of the kit on a throwaway repo |
| `~/.config/opencode/agents/worker.md` | Worker agent: model, allow-list permissions, worker rules |

All paths below are relative to `~/.claude/skills/worker-kit/`.

## Worker model

Default: `vua/deepseek-v4.1-flash` (set in `worker.md`). Escalation:
`vua/glm-5.3` (a different model family), then Claude. V4.1 Flash beats V4 Pro
on agentic coding (DeepSWE 77.0 vs 62.7, vendor numbers), so Pro is not an
escalation (declare a model in the
`vua` provider of `~/.config/opencode/opencode.json` before first use; back the
file up first). Free tiers (`opencode/…-free`) run out of quota.

To change it ("đổi model worker"): read `model:` in `worker.md`; list candidates
from `opencode models`; ask with AskUserQuestion (current first); persistent →
edit `model:`, one run → `--model`; then run `preflight.sh --model <id>`. Do not
append reasoning variants (`#max`, `#high`) unless a short trial passes.

## Flow

### 0. Recon (optional, worker)
When planning needs many reads, write `templates/recon.md` with exact Finder
requests (finder-kit §3 shape) and, for any caller list, an `rg` cross-check
(the Finder graph misses Dart static calls). The worker writes an evidence pack;
Claude plans from it and reads source only for lines the brief will quote.
Run it like any brief (preflight + confirmation), `--check "test -s <pack>"`.

### 1. Plan (Claude, with finder-kit)
Read `lessons.md` first. Create the workspace:
`scripts/ws.sh init --repo <repo> --topic <slug>` → `WS=…`. Follow `finder-kit`
for discovery (global CLAUDE.md requires it); recon packs go to `$WS/evidence/`.
Fill `$WS/plan.md` (from `templates/phase-plan.md`) and put cross-phase
decisions in `$WS/rulings.md`:
- one phase = one observable outcome; split into clusters of 1-4 tasks, each
  cluster ending in a gate that runs real repo tests/analyze;
- each phase owns its files; record `Depends on`; group independent phases
  (G1, G2, …); default execution is one phase at a time, in order;
- runner `worker` for well-specified typing; `Claude` for design, risky areas
  (auth, payments, migrations, Firebase/Remote Config), shared touchpoints
  (`pubspec.yaml`, generated code, l10n, routes, DI), and edits of a few known
  lines already in context (a brief would cost more than the edit).

### 2. Review the plan (Claude) — checklist from lessons.md
For every task and cluster:
1. Exact `file:line`; current code quoted verbatim; new code complete enough to
   copy — including docstrings, comments, and parameter names a semantic change
   affects.
2. "Do" defines the behavior; the gate only confirms it. No spec hidden in a gate.
3. Every new or changed behavior gets a test in the repo's test files; the gate
   runs those files.
4. Domain details (currency, rounding, locale, copy text, units) are decided in
   Context or Rulings.
5. Every caller and test of each changed symbol is listed (Finder `context`/
   `impact` **plus** `rg` cross-check) with an explicit instruction for each.
6. Side effects traced: network calls, timers, DI lookups, logout/dispose/resume.
7. Instruction and gate agree; gates assert behavior, not a literal to copy.
8. Verify/gate commands exist in the repo, are scoped, and never search files
   that contain the brief's own text.
9. Counts/lists say exactly what to count; exhaustive lists come from `rg`.
10. Idle timeout exceeds the slowest command (keep the 600 s default for Flutter).
Then report the plan and the review to the user and wait for approval.

### 3. Write the brief (after approval) — precision rules
Copy `templates/brief.md` to `$WS/briefs/<phase>.md`. Aim for ≤ 2 worker tool
calls per task (one edit per Edit block, one Verify shell call) plus one log
append per cluster:
- Every change is an **Edit** block: `**Edit** \`path\`` + ```` ```old ```` block
  copied verbatim from the current file (unique, with enough surrounding lines)
  + ```` ```new ```` block with the complete result, including docstrings,
  comments, parameter names, and the test. Empty `old` = new file.
- Within one dispatch, every `old` must match the code as it is before the run
  (edits of the same region go in different clusters).
- Context names everything the worker needs; Finder requests are "none" unless
  a gap is unavoidable. No "read X to understand" steps.
- Verify = one shell line per task (format + analyze/test of touched files).
`dispatch.sh` refuses briefs with missing sections, unfilled placeholders, or
Edit blocks whose `old` is not found exactly once (`LINT FAIL`, exit 3) —
before any token is spent.

### 4. Preflight and confirm (before every new phase)
1. `scripts/preflight.sh --cwd <repo>` (`--model <id>` to try another). Checks
   opencode, agent, model listed, a real reply, a real tool call, Finder.
2. `NOT_READY` → show the failing line, offer the model menu, preflight again.
3. `READY` → AskUserQuestion: runner (opencode, agent `worker`), model, reply
   and tool times, Finder, brief, Scope, gates. Options "Chạy" (recommended),
   "Đổi model", "Huỷ". Dispatch only on "Chạy".
`dispatch.sh` refuses (exit 5) without a preflight for that model in the last
30 minutes. Resumes inside a confirmed phase reuse the confirmation.

### 5. Run cluster by cluster (one Claude wake-up per cluster)
```bash
D=~/.claude/skills/worker-kit/scripts/dispatch.sh
$D $WS/briefs/<phase>.md --cwd <repo> --cluster C1 --baseline "<verify>" --check "<C1 gate>"
$D $WS/briefs/<phase>.md --cwd <repo> --cluster C2 --resume <SESSION> --check "<C2 gate>"
```
Run it with the Bash tool in the background (`run_in_background`, output to
`$WS/reviews/<phase>-<cluster>.out`): Claude is woken once, when the run ends.
Then read only the result lines:
`grep -E '^(TOKENS|CHANGED|QUESTION|ASK|CHECK exit|CHECKOUT|REVIEW|BRIEF_TAMPERED|STALL|DONE|FAIL)' <out>`.
Use the Monitor tool (live STEP events) only when the user asks to watch.
The script measures T0 once (`--baseline`), streams `STEP` events (each worker
tool call), runs the gate, and writes the **review package** to
`$WS/reviews/` (gate output + diff of every changed file) and a row to
`$WS/ledger.md` (with steps and tokens). Claude reads `CHECK exit=` (the
verdict), `TOKENS steps=…` (precision feedback: many steps → the brief was
not precise enough → lesson), `CHANGED` (the user's own dirty files and build
artifacts are excluded), and the review package. Open the real code only for
risky hunks. Then record decisions in the brief's **Rulings**, update the phase
plan's "Done by" and Status, and continue. Never edit a brief, `worker.md`, or a
kit script while a run is in progress.

Events: `LINT`, `PREFLIGHT`, `START`, `RUNNING`, `PROGRESS`, `RETRY`, `STALL`,
`WORKER exit=`, `SESSION`, `COST`, `ERROR`, `SUMMARY`, `CHANGED`,
`BRIEF_TAMPERED`, `QUESTION`, `ASK`, `CHECK exit=`, `CHECKOUT`, `LEDGER`,
`DONE`, `FAIL`. Exit codes: 0 done, 3 lint, 4 questions, 5 no preflight,
6 tampered, 124 start hang, 125 stall, else the gate's or worker's code.

### 6. Loops
**Questions (exit 4).** Code facts → answer from Finder/`rg`/a read. Product,
scope, or risk decisions → AskUserQuestion with the worker's OPTIONS. Record the
decision in Rulings, fill `templates/answers.md`, and resume:
`$D <answers.md> --cwd <repo> --resume <SESSION> --protect <brief> --check "<gate>"`.
Max 3 question rounds per phase, then take it back.

**Red gate or wrong diff.** Short fix brief (failure output + exact change),
resume the same session. Rounds 1-2: same worker. Round 3: fresh session on a
stronger model (own preflight + confirmation) with a fresh brief that carries
the Rulings. After that: Claude finishes the cluster and adds a manual ledger
row (`Claude (fix)`). Edits outside Scope → revert only those edits, keep the
user's prior changes.

**More work.** Depends on this session's context → answers-style brief with
"Extra tasks" and `--resume`. Independent → a fresh brief (no history re-read).

### Session hygiene (saves most of Claude's tokens)
- Start every phase in a fresh session (`/clear` or a new `claude`). First turn:
  `ws.sh status --repo <repo> --topic <slug>`, then read only `plan.md`'s phase
  row and that phase's brief. Everything else lives in the workspace.
- Inside a phase: one confirmation (preflight + AskUserQuestion), one wake-up
  per cluster, one short status line to the user per cluster.
- Review: read the review package's gate lines and the diff of risky files
  only; never re-read the whole code base.
- Write decisions to `rulings.md` / the plan immediately, so a fresh session
  never depends on chat history.

### 7. Phase review and retro (Opus, mandatory)
1. Run the phase's full verify command once yourself (tail only) and compare
   with T0. A "pre-existing" failure not in T0 is unproven.
2. Grade the code: spec match, tests added, pattern followed, edge cases, no
   dead code, docstrings/names consistent.
3. For each defect name the root cause — **plan**, **worker**, or **kit** —
   add a row to `lessons.md` ("Rule for future plans"), fix the remaining
   briefs now, tighten `worker.md` for repeated worker causes, fix kit causes in
   the kit (then rerun `selftest.sh`).
4. Report to the user: what now works, gates and verify results, the grade and
   lessons table, ledger rows (who did what), open items.

### 8. Traceability and commits
`worker-ledger.md` (next to the brief, or `--ledger`) gets one row per run from
the script: time, brief, cluster, runner/model, session, worker exit, gate exit,
result, changed files, tokens. The phase plan's "Done by" points at those rows.
Claude never commits. When the user commits, offer a trailer such as
`Worker: vua/deepseek-v4.1-flash ses_ab12 (P1 C1-C2)`; add it only if they want.

## Self-test (real, no fakes)
`scripts/selftest.sh` builds a throwaway git repo under `/tmp/worker-kit/selftest`
and runs real dispatches on the configured model: lint refusal, preflight guard,
cluster + gate + ledger, attribution excluding user files, a real contradiction
that must end in `ASK`, answers + resume, and a plan-edit request the worker
must refuse. It needs a fresh preflight and the user's confirmation like any
run. Rerun it after any change to the scripts or `worker.md`.

## Parallel runs (v7, designed, not built yet)
Until v7 ships: never run two workers in the same working tree. Chosen design:
- Several workers per phase ("lanes"), each in its own git worktree that starts
  from the user's current tree (tracked edits + untracked files; never
  secrets); each lane owns its files; contracts between lanes are fixed in the
  plan; shared touchpoints (`pubspec.yaml`, generated code, l10n, routes, DI)
  belong to one lane or to the integrator step.
- Default 2 lanes per phase (raise to 3 after measuring the provider and CPU).
- Integration worktree ("bếp tổng"): merge lanes in plan order — git 3-way
  merge → re-apply the lane's Edit blocks on the merged code → integrator
  worker on `vua/glm-5.3` → Claude/user
  for conflicts of intent. Regenerate lock/generated files after merging, never
  merge them.
- ONE phase gate (analyze + unit/widget tests, no secrets) in the integration
  worktree; green → back up the user's tree as a patch → apply the phase patch
  → secret-dependent checks in the main repo → retro → next phase. Red → map
  failing files to lanes → fix brief to that lane's session.
- Risks to handle in v7: ignored-but-needed files (`.fvm`, `lib/gen`), base
  drift if the user edits the tree mid-phase, flaky tests (rerun once against
  T0), concurrent questions (rulings frozen while lanes run), provider
  concurrency limits, cleanup of worktrees/processes, worktrees under
  `~/.worker-kit/wt` with 700 permissions.

## Sources of the design
- obra/superpowers (★305k): task = smallest unit with its own test cycle,
  review gate before the next, script-written ledger, rulings, batching
  same-shape edits, escalate to a stronger fresh implementer.
- github/spec-kit (★143k): phases with independent test criteria; parallel only
  for different files without dependencies.
- eyaltoledano/claude-task-master (★28k): dependencies and status per task.
- Not used: `opusplan`/subagent `model:` (Anthropic models only); gateways like
  claude-code-router (planner would go through a proxy); Orchestrator.inc (a
  separate app whose workers commit and open PRs).
