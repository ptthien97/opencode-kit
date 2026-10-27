---
name: finder-kit
description: "Codebase work with Finder end to end: discover evidence, frame scope, spike risky assumptions, debug, plan, implement, test, verify, review, and read Finder packs, with poteto-mode principles built in. Use for any multi-phase code task, or whenever Finder output begins with \"FCP/\" or is a JSON object with `intent` and `code`."
---
<!-- finder-kit-skill-v7 -->

# Finder Kit

Pick the shortest workflow that satisfies the request. Carry authorized
implementation through verification. Stop after a standalone question, plan, or
review when that is all the user asked for. Roles are responsibilities, not
processes: one agent can frame, plan, implement, and verify in sequence. Infer
workspace, scope, and supplied evidence from the conversation; ask only for
information that prevents correct work. An unknown blocks work only when it
prevents a required claim, implementation decision, or acceptance check.

Evidence ranking, strongest first: **runtime output > fresh source read > Finder
record > memory/assumption.** Label every technical claim: measured (cite output),
read (cite `file:line`), inferred, or guess. Never hand the user a check you could run.

**Bold names** are poteto-mode principles, applied where they appear. When asked
whether to do something, or shown an approach, give real judgment and push back
when it does not earn its place.

## 1. Workflow size

| Size | When | Phases |
|---|---|---|
| Quick | small, understood change | derive one compact task in place → implement → verify |
| Standard | cross-file or partly unknown | explore unknowns → frame blocking decisions → spike → plan → implement/verify each dependency before its consumer |
| Bug | reported defect or regression | debug (reproduce → root cause) → failing regression test → implement → verify |
| High-risk | security, data loss, compatibility, ops | Standard + explicit invariants + rollback; independent review when requested or required by policy |
| TDD | requested, or behavior is easy to pin | acceptance → failing test (observed red) → implement → verify |

These are routing choices, not locked modes. When risk or scope changes, update
only invalidated decisions and tasks. Keep valid evidence and completed work.

## 2. Gate (before any workspace-scoped Finder call)

1. Global `/mcp` endpoint: send `workspace_full_path` = exact absolute workspace
   root on every scoped call; several roots match → `list-repos`. Repo-scoped
   `/mcp-repo/<id>` endpoint: the URL already binds the repository, so omit the
   path argument and follow the advertised tool schema. Ask only if the request
   cannot resolve the workspace.
2. Call `index-status` before the first query. Reuse readiness until a query reports
   warming/partial or the workspace changes.
3. Not approved → show that exact path and request consent: on `/mcp`, propose
   `approve-indexing` via the harness confirmation flow; on `/mcp-repo/<id>`, which
   has no `approve-indexing` tool, point to the product approval control. Wait for
   explicit consent. Recorded approval needs no repeat.
   Never infer consent from a code task. Never widen to a parent directory. Home
   directory or filesystem root → do not propose it (server refuses); ask for a
   project directory under it.
4. **Readiness wait budget.** Warming/partial → at most two rechecks, 30–60 s apart,
   per readiness episode, doing independent work between them. Still not ready →
   native evidence for the active task, and disclose which graph/index claims are
   unavailable. A phase change does not reset the budget. A new episode needs
   observed progress or a user-requested retry. Approved but unindexed with no
   indexing flow available → report it, use native evidence. Resume Finder when a
   later status shows readiness. If native tools cannot supply required evidence,
   report that gap as blocked instead of polling indefinitely.
5. Pending approval or readiness never blocks independent native work. Native
   fallback neither performs nor authorizes indexing, and grants no access to
   another workspace. Finder unavailable or erroring → native tools, record the
   limitation.

## 3. Ask sharp, read little

**Who writes requests.** The strongest model in the session writes every Finder
request. When delegating, pass the exact request text, filters, and a read budget.
Workers return `file:line` citations and gaps, never raw packs. Do not forward vague
user wording verbatim.

**Request shape.** One request = one behavior in one subsystem:

```text
<behavior in one sentence, in the codebase's terms>. Likely identifiers: <3-8 guessed
type/function/config/error names>. <Production code | tests | config>.
```

- Add `filter_path` (a directory seen in the tree) and `filter_lang` when obvious.
  Guessed identifiers need not be right; they move the query into code vocabulary,
  and each one that names a real definition joins the candidates the reranker judges.
- Known exact name → short request naming only it (`where is run_query_op defined
  and who calls it`). If every identifier in a short request is a defined symbol,
  Finder answers locally in milliseconds, definition first, then only the chunks
  that use the name. This replaces grep for that name.
- Split only across subsystems (UI vs storage). Max three requests per question.
  Independent requests can run in parallel.
- Default to one behavior per request with guessed identifiers and filters. Naming
  aspects for that one behavior (definitions, callers, tests) also works and pulls
  tests into the same pass; never use one request to cover several behaviors.
  Callers and blast radius come from `context`/`impact`, not from more `finder` calls.
- Weak: `How does auth work?` Strong: `Login flow: login controller submit, auth
  service login call, token storage and refresh-token interceptor. Likely
  identifiers: LoginController, AuthService.login, TokenStore,
  RefreshTokenInterceptor. Production code.` + `filter_path: "lib/"`, `filter_lang: ["dart"]`.

**Triage.**
- Rank order is the signal. `score` is a reciprocal rank (1, 0.5, 0.33…), not a
  relevance value; never threshold it.
- Read the top three distinct code files. Ranks past ~8, one-line snippets, and
  test/bench/script/doc hits are weak leads unless the question is about them.
- Read at most five files before the first answer draft.
- Graph records are usually `inferred`: use them to pick the next `context` target,
  not as proof.

**Pin.** Once a symbol is named, stop calling `finder`:

| Known | Tool |
|---|---|
| Location/behavior unknown | `finder` |
| File known, range unknown | `file-finder`, then read returned ranges, widened as needed; never for repo-wide discovery |
| Symbol known, callers/callees/tests | `context` |
| Symbol known, "what does changing it affect?" | `impact` with required `direction`: `upstream` = who calls it, `downstream` = what it calls; optional `max_depth`, `budgets` |
| Literal/symbol, exhaustive matches | native exact search |
| File and range known | fresh source read |
| Exact change set or history | native git |

A selector is an object with exactly one key, the literal word `fqn`, `symbol_file`,
or `file_line`, never the symbol's own name:
`{"symbol_file": {"symbol": "EasySpeakCredits", "file": "lib/data/models/easy_speak_booking.dart"}}`
(repo-relative path). `impact`/`context` are local graph lookups. `ambiguous_target` → refine the selector
from its candidates, never auto-pick. `warming` → retry after indexing; it is not
"no impact". Empty relation set = "not observed within budget", never "provably
unaffected". `graph_truncated` → the affected set is a lower bound.

**Stop.** Answer or act when each required claim has a fresh `file:line`. Follow up
only for a named gap, at most two more requests (a graph-ready retry counts toward
this), each rewritten with identifiers learned from files already read. Never
repeat a near-identical request.

## 4. Reading packs (FCP/2, FCP/1, JSON)

The pack is a ranked evidence map, not the answer.

| FCP text | JSON pack |
|---|---|
| header `q`, `task`, `route` (FCP/2 adds `root`) | `intent.task`, `intent.kind`, `intent.route` |
| `C` records in rank order (FCP/2: one per file) | `code.items[]`; `evidence.source_range` = `file`, `line_start`, `line_end`; `content` is a truncated preview |
| `A`, `D`, `I`, `G`, `O`, `B` (FCP/2 folds `I` into `D`) | `architecture`, `dependencies` + `data_flows`, `impact`, `git`, `ownership`, `business_rules` |
| suffix `?` / `!`, `U` records | `evidence.state` = `inferred` / `stale`; `unknowns[]` |
| graph-pending notice / `U` diagnostics | `diagnostics.warming`, `.graph_pending`, `.truncation` |

Default output is compact FCP/2: one `C` line per file, paths relative to `root`,
at most ~15 distinct code files per pack. A server started with
`FINDER_STRUCTURED_OUTPUT=1` returns the JSON pack instead; Claude Code then shows
only the JSON and may save a large pack to a file. `truncated_count` > 0 → a section
was cut. Extract ranked locations before reading source:

```text
jq -r '.code.items[:8][] | .evidence.source_range | "\(.file):\(.line_start)-\(.line_end)"' <pack>
jq -c '{warming: .diagnostics.warming, graph_pending: .diagnostics.graph_pending, unknowns: [.unknowns[].evidence.diagnostics]}' <pack>
```

**FCP/2:**

```text
FCP/2 root="<workspace>" q="<escaped query>" task="<kind>" route="<route>"
C src/a.rs:10-29 handle | 88,140 Store::save | 300 | +2
D? handle ← main, serve +3 in 4 files → parse_args, Store::save +6
G src/a.rs: 5 commits +120 -14
U diag="..."
```

- Lines before the header are metadata, not records: a route note such as
  `route: keyword (jev 0.44)`, or a readiness notice.
- Paths are relative to `root`. `C`: path ends at the first `:`; split the rest on
  ` | `, best hit first; each hit is a range (or comma-joined spans) plus symbol;
  `+N` = hits omitted. On a `C` line, `?`/`!` describe the weakest hit.
- `D?`: `← callers` (`in N files` when cross-file), `→ callees`, capped with `+N`.
  `← N callers (by name; verify)` = likely name collision; confirm with `context`.
- `G`: per-file churn. `A`, `O`, `B`, `U` use FCP/1 field syntax.

**FCP/1:** header `FCP/1 q="…" task="…" route="…"` (a readiness notice may precede
it). Each other non-empty line is one record `<prefix><state> <fields>`. Prefixes:
`C` location only (`C path:start-end`; parse only the final `:start-end` as range;
`C` never contains source bodies), `A` architecture/entrypoint, `D` dependency
(`type=dep`) or flow (`type=flow`), `I` impact/callers/tests/risk, `G` git, `O`
ownership, `B` business rule, `U` unknown or truncation diagnostic. State suffix:
none = proven, `?` inferred, `!` stale. Fields: `type=`, `claim="…"`, `reason="…"`,
`diag="…"`, `src="path:start-end"`, `git="path@object"`, `content="…"`. Quoted
values escape `"` `\\` tab LF CR as `\"` `\\\\` `\\t` `\\n` `\\r`, other controls as
`\\u{hex}`; parse escapes before interpreting a quoted field. Split records only on
physical newlines; prefix-looking text inside a quoted value is not a record.
`U reason="truncated"` / `"output_cap"` → the pack is partial. Absent record types
are intentional.

**Evidence workflow.** Confirm header query/route match the task → fresh-read the
top three `C` files → use other records as leads, verifying `?` before relying on
it → refresh `!` records you need → report each relevant `U` without blocking on
unrelated ones → search again only for a named gap. Preserve proven / inferred /
stale / unknown distinctions in conclusions. A pure location answer ("where is X")
needs no extra read; claims about behavior and every edit do.

**Graph-pending.** A pack that opens with `(index is resolving the call graph;
showing vector-only results without callers/callees)` or carries
`U reason="Call-graph indexing is pending..."` is vector-only: missing callers or
edges prove nothing. `index-status` can report `ready` while a pack still carries
this record, and `context`/`impact` may already return edges: use them, labeled
possibly incomplete. Share the §2 wait budget. When ready, retry the affected query
once; the fresh result must no longer carry the limitation. If it persists, use
current source + scoped native caller search, disclose incomplete graph coverage,
and block only claims that need the missing evidence. A user may accept a partial
answer, but absent graph edges never become proof of absence.

## 5. Phases

### Explore
1. Reuse evidence already in the conversation. Look at the top-level tree once if
   the layout is unknown (it supplies `filter_path`).
2. Ask 1–3 requests (§3), triage, fresh-read, pin.
3. Answer with `file:line` grouped by behavior, each claim's state (proven,
   inferred, stale, unknown), and remaining gaps. Cite the files that carry the
   behavior, not every hit. Search absence is not proof of absence unless the scope
   was searched exhaustively. No code changes. Inside a larger workflow, hand the
   map to the next phase.

**Exit:** each required claim has current evidence or a stated material gap.

### Frame
1. Separate explicit requirements from inferred repository conventions.
2. Find ambiguities that change observable behavior, compatibility, data access, or
   acceptance. Settle code facts from evidence first.
3. Resolve routine choices from established patterns; state material assumptions.
   Before asking "which approach / how does X behave": if the answer is observable
   by running something, spike it and let the result decide. Ask only for product
   or preference calls no experiment can settle; keep working on independent parts
   meanwhile (**Never Block on the Human**).
4. Product tradeoffs favor the user's experience over implementation convenience
   (**Experience First**).
5. Publish scope, non-goals, preserved invariants, acceptance boundaries,
   assumptions, unresolved decisions with their impact. Nonblocking questions stay
   visible without blocking the frame; a blocking question names exactly the
   decision needed. An answer that changes scope → update the frame and continue
   within the new authorization.

**Exit:** no unresolved decision prevents correct implementation.

### Spike (Micro-Spike Grounding)
Static evidence shows what code says, not what it does at runtime. Before
finalizing a Standard or High-risk plan:
1. Name the highest-risk assumption static evidence cannot settle: third-party
   API/library behavior, version compatibility, serialization/parsing, type
   conversion, async/concurrency, platform quirks.
2. Current source or docs already settle it → cite them and skip.
3. Otherwise write one throwaway probe (10–30 lines, or one isolated test) that
   answers one yes/no question. Put it in the scratchpad directory or a temp test
   file. Use the project's own toolchain and pinned versions so the result transfers.
4. Run it. Read stdout, stderr, exit code, and the actual data shape.
5. Pass → cite the observed output in the plan. Fail or surprise → revise the
   hypothesis and probe again.
6. Two failed probes or fixes sharing one premise → write the premise down and test
   it directly. False → change the approach, don't force it (**Attack the Premise**).
7. Novel interaction or architecture with no precedent → build 2–3 competing
   throwaway probes and compare before committing (**Exhaust the Design Space**).

Rules: spike code never becomes production code; delete it when done. No writes to
real data, shared services, or project dependencies/lockfiles; prefer mocks and
local fixtures; no state-mutating network calls. Truly cannot run (physical device,
credentials, prod access) → mark the assumption `UNVERIFIED` in the plan with the
exact command for the user. Skip for Quick, mechanical, or already-tested changes.

**Exit:** the core approach has runtime evidence, or its risk is labeled UNVERIFIED.

### Debug
1. Reproduce first, on the same surface the user hit (app, test, CLI). Record the
   exact command or steps and the observed failure. No repro yet → gather runtime
   evidence (logs, a probe) before touching code.
2. Trace the symptom back to the first place the system went wrong, using Explore
   and `context` for the call path. Fix it there, not where it surfaced. A guard is
   a fix only when the state it handles is legitimate (**Fix Root Causes**).
3. Two fixes sharing one premise failed → stop, write the premise down, test it
   directly (**Attack the Premise**).
4. Capture the bug as a failing regression test when a seam exists (Test: author),
   then fix through Implement and Verify.

**Exit:** root cause named with runtime evidence; the regression check fails before
the fix and passes after.

### Plan
1. Reuse the evidence map; do not query once per task. Unknown locations → Explore.
   Blocking product decisions → Frame. Risky runtime assumptions → Spike.
2. State observable acceptance, constraints, assumptions. Use `WHEN <condition> THE
   SYSTEM SHALL <behavior>` only where it clarifies conditional behavior.
3. Describe only design decisions a reviewer needs: affected interfaces, data flow,
   compatibility, risks. Follow repository patterns; no invented architecture sections.
4. Name the data shape first and encode the domain in a structure (typed model,
   state machine, table/registry, reducer) instead of scattered conditionals
   (**Model the Domain**). Fold a new requirement in as if it had been foundational,
   not bolted on (**Redesign from First Principles**). For migrations, move callers
   to the new API and delete the old one in the same wave, with no throwaway
   compatibility states (**Migrate Callers Then Delete Legacy APIs**,
   **Outcome-Oriented Execution**).
5. Create tasks (§6) with bounded files, acceptance, and verification commands
   grounded in repo scripts/tests. Each task ends in a check, so the sequence proves
   itself (**Sequence Work into Verifiable Units**). New files need an
   evidence-backed purpose, not fictional citations. High-risk → rollback.
6. Record real dependencies; acyclic. Tasks on the same file run sequentially.

Read-only inspection commands are allowed. Planning edits no production code and
claims no verification. Report blocked only for a decision/evidence gap that
prevents planning that change. A plan-only request ends here.

**Exit:** every change has bounded files, measurable acceptance, acyclic deps.

### Implement
1. Take one task or a caller-managed list. Small understood request → derive a
   compact task in place. Missing design/dependency decisions → Plan.
2. Start a task only after its prerequisites are verified; a pending prerequisite
   is a scheduling condition, not a reason to replan. Increment `attempts` once on
   entering the pass; local edits and test reruns inside a pass do not increment it.
3. Fresh-read relevant ranges; reuse plan citations; Finder only for missing/stale
   evidence. Cited ranges are leads, not limits on adjacent edits.
4. Implement the authorized outcome with the smallest change that solves it; bias
   to deletion and remove dead weight before adding (**Laziness Protocol**,
   **Subtract Before You Add**). No new layer or wrapper for a single caller;
   validate at system boundaries and trust internal types (**Minimize Reader
   Load**, **Boundary Discipline**). A sweep across many call sites → a codemod or
   script the reviewer can rerun, not hand edits (**Build the Lever**). Preserve
   unrelated changes. A necessary extra file → update the task boundary and check
   ownership; ask only if scope or permission actually expands.
5. Run relevant checks; record command, result, source/input context. TDD → satisfy
   the existing red test without weakening its assertion.
6. Record the scoped diff + check evidence as `candidate_complete`, then continue to
   Verify when the user asked for completed work. A candidate alone is not done.
   Report: task id, files touched, diff reference (an uncommitted snapshot or patch
   is fine; no commit needed), attempts, check evidence, gaps.

Delegate only independent work, when the harness supports it and it justifies the
overhead: separate files, findings back to the parent, merge before verification.
Sequential work stays available when delegation is not. Route bulk output to
subagents and keep summaries in the main thread (**Guard the Context Window**). You
own delegated work: review its diff and write your own summary instead of passing
its report through. Commits need the user's requested scope; a handoff is not an
instruction to commit.

**Exit:** scoped candidate diff, attempts recorded, invariants preserved.

### Test: author (test-first)
1. Find the public seam and repo test convention. Write the smallest meaningful
   regression test; no production edits.
2. Run it; confirm it fails for the intended missing behavior. Syntax errors,
   missing deps, broken fixtures are not RED: repair permitted setup or report.
3. Already passes → check the assertion exercises the behavior; report existing
   coverage or fix an inadequate test. Never force a false failure.
4. Return test diff, acceptance, exact command, observed failure.

Expected red does not increment `attempts` or fail a task. Keep assertions through
GREEN and REFACTOR. Assert what the code's users can observe, so the test fails when
behavior breaks and survives internal changes (**Test Behavior, Not
Implementation**). Use Finder only for missing test conventions or affected
behavior. Under TDD, continue to Implement then Verify; standalone authoring stops here.

**Exit:** test fails for the intended reason (or behavior provably already exists).

### Test: verify
1. Inspect the candidate and its coverage, including boundary and error cases.
   Do not modify the candidate here. No formal task is needed for standalone
   verification; derive checks from repo scripts and acceptance when none were given.
2. Run required commands. Reuse a result only when command, relevant
   source/config, inputs, and environment are unchanged; say what was reused.
3. Stale command path/option → correct it only with repo evidence of an equivalent
   check, record why, keep the acceptance assertion. A weaker or different
   assertion means revisiting acceptance, not editing the test until it passes.
4. `verified` only when checks pass and acceptance holds. Executed failing check →
   `failed`. Required check unavailable after recovery → `blocked`. Separate
   pre-existing baseline failures from regressions.

Verify against the real artifact, not a proxy or "it compiles" (**Prove It
Works**). Before trusting or reporting a measured number (speedup, latency,
regression), find what limits it and rule out that it measured something else
(**Explain the Number**). Verification never increments `attempts`. Success
completes the work unless review is requested or required; do not append review
automatically. Report: mode, checks with actual results, coverage/acceptance
conclusion, gaps. Neither test mode grants independent approval.

**Exit:** required checks pass and acceptance is satisfied.

### Review
Report findings; never edit the candidate. Approval is independent only if the
reviewer did not implement the change; label self-checks as such. No independent
reviewer available → report verified work and the pending review requirement.
Infer and record the scope before reviewing; ask only when competing scopes would
change the result. Apply requested path limits consistently.

| Scope | Native evidence |
|---|---|
| Branch/PR | resolve base and head to SHAs, record merge-base semantics, diff |
| Two-dot range | resolve endpoints, compare trees |
| Single commit | `git show <sha>` |
| Staged / unstaged | `git diff --cached` / `git diff` |
| All local | both diffs + `git status --short` + `git ls-files --others --exclude-standard` |
| Supplied patch | inspect patch and base; disclose if the base cannot be rebuilt |

For local changes, record HEAD and snapshot patch, file list, and untracked
contents; read scoped untracked files natively. Recheck scope before the verdict;
if it moved, update findings or name the reviewed snapshot. Empty scope → "no
changes to review". Never rebase or modify the worktree to simplify review.

1. Read the exact change set. Derive intent from the request/spec and repo
   contracts; report missing intent if it blocks judging correctness.
2. Inspect introduced behavior, affected callers, data flow, tests. Prefer
   `impact`/`context` on changed symbols over broad queries.
3. Run focused checks. Separate introduced from reproducible pre-existing
   failures; a failing test does not prove the diff caused it.
4. Each finding: severity, trigger, consequence, current `file:line`. Separate
   confirmed defects from unresolved risks. Also flag hard-to-trace code: extra
   layers, one-caller wrappers, wide mutable scope (**Minimize Reader Load**).
5. Bot or automated review comments → assess each on its merits; dismiss noise with
   a concrete reason instead of churning code.

| Verdict | Condition |
|---|---|
| `approved` | independent review; checks/acceptance pass; no major/blocker defect |
| `changes_required` | confirmed major/blocker defect or acceptance failure |
| `blocked` | essential scope, evidence, access, or required check unavailable after recovery |

A severe defect is `changes_required`, never hidden behind `blocked`; with some
checks missing, report `changes_required` plus the verification limitation. Review
alone does not authorize fixing or publishing. Output: scope/snapshot, findings,
verdict, check summaries, gaps. Cite findings; no patch or log dumps, no secrets.

**Exit:** fixed scope examined; findings, check evidence, verdict recorded.

## 6. Task record

Use for structured handoffs; a compact equivalent is fine for small changes. Use a
harness task API only if its schema fits.

| Field | Req | Meaning |
|---|---|---|
| `version` | yes | `2` |
| `id` (or `task_id`) | yes | stable dependency id |
| `outcome` | yes | observable intended behavior |
| `state` | yes | starts `planned` |
| `owner` | yes | `planner` / `implementer` / `verifier` / `reviewer` / `system` |
| `acceptance` | yes | ≥1 measurable criterion |
| `verification` | yes | ≥1 `{ command, expected }` |
| `files` | before edit | bounded paths; ranges are leads |
| `actor` | no | transition author, defaults to owner |
| `deps` | no | prerequisite ids, default `[]` |
| `symbols`, `citations` | no | evidence leads; new files need none |
| `unresolved` | no | gaps + effect on acceptance |
| `risk` | no | `low|medium|high|unknown`, default `medium` |
| `rollback` | high risk | concrete recovery approach |
| `attempts` | no | default `0`, implementer-only |
| `failure_fingerprint` | no | stable summary of latest failure, no secrets |

```yaml
task:
  version: 2
  id: quota-default
  state: planned
  owner: planner
  outcome: "An empty database uses the configured default quota"
  files: ["src/user.rs", "tests/quota.rs"]
  acceptance: ["A user with no stored quota receives DEFAULT_QUOTA"]
  verification:
    - command: "cargo test --test quota empty_database"
      expected: "The empty-database quota assertion passes"
  deps: []
  attempts: 0
```

States: `planned` → `running` → `candidate_complete` → `verified` | `failed`;
coordinator may set `blocked` (unresolved prerequisite) or `skipped` (removed from
scope). Verification must fit the change: meaningful existing checks for
low-impact edits, new tests where they protect behavior. It must exercise the
acceptance criterion; a green command that does not is insufficient. If automation
is inappropriate, record a reproducible inspection command and its observable
evidence. Keep actual command results in the verification report the handoff
references. Concurrent tasks own non-overlapping files. Review issues its own
verdict without erasing history.

## 7. Recovery and bounds

| Trigger | Action |
|---|---|
| Nonblocking unknown | keep it in the report, continue |
| Evidence missing for a decision/check | one focused discovery of that gap; native fallback allowed |
| Runtime behavior uncertain | Spike, don't ask |
| Reported defect | Debug: reproduce before changing code |
| Missing product decision | resolve from evidence or ask; continue independent work |
| Dependency cycle, incompatible scope, overlapping edits | revise the task/dependency boundary |
| Candidate fails acceptance | failure evidence back to Implement for a diagnosed repair |
| Review finds a code defect | repair that task, rerun invalidated checks |
| Review exposes a wrong requirement/test expectation | update that decision before implementing |
| Check cannot execute | permitted environment recovery; report blocked only if still unavailable |

- **Attempts:** only Implement increments them (Test, Review, routing never do);
  max three implementation passes per task. At the limit, keep the candidate and
  report the failure. A fourth needs a materially revised task and an explicit
  explanation, never a silent reset.
- **Re-entry:** at most twice per phase for the same unresolved issue, each with new
  evidence, a corrected assumption, or changed source/environment. Repeated
  identical failure without a new diagnosis does not justify rerunning. Bounds
  apply per issue, not to unrelated tasks. Recovery exhausted → report the specific
  blocker and continue independent work when useful.
- A failing test is `failed` / `changes_required`, not an infrastructure block. An
  expected TDD red completes authoring; it is not a failed implementation.
- Invalidate only evidence/checks the change affects. Mode switches, handoffs, and
  nonblocking unknowns do not restart the workflow. Reuse evidence only while its
  files and inputs are unchanged; fresh-read before edits and exact claims.
- User stop = pause: preserve work, report what remains, never label it a code
  failure, no automatic rollback. High-risk rollback is recorded, never executed
  automatically.

## 8. Output

Human-facing: concise prose with findings, citations, command summaries,
unresolved requirements. Structured envelope only for a real tool/handoff consumer:
`mode`, `input`, `output`, optional `handoff`, `completion: { state: complete |
blocked | failed }`.
- `complete`: the phase met its exit. A plan is not implemented; a candidate is not
  verified; self-verification is not independent approval.
- `failed`: an executed check demonstrated a failed acceptance criterion.
- `blocked`: missing evidence, access, authorization, or product decision after
  permitted recovery. Name what would unblock it.

Handoffs carry only the next phase's inputs, task/evidence references, and material
gaps. Existing authorization persists across phases; a handoff needs no new permission.
