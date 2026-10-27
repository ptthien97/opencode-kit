# worker-kit v6.1 — flow

```
 ┌──────────────────────────── SHARED WORKSPACE  ~/.worker-kit/ws/<repo>/<topic>/ ───────────────────────────┐
 │  plan.md   rulings.md   briefs/   evidence/   reviews/   ledger.md          (ws.sh status → ~400 tokens)    │
 │  Claude writes ✍          worker reads 👀          scripts append 🤖          nothing lost to compaction     │
 └──────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                 ▲ writes                      ▲ reads                           ▲ appends

 YOU            CLAUDE (Opus)                    SCRIPTS (trusted, no tokens)        WORKER (vua/deepseek-v4.1-flash)
 ───            ─────────────                    ────────────────────────────        ────────────────────────────────
 "plan X" ──►  0. recon brief (optional) ───────► dispatch ─────────────────────────► runs Finder requests → evidence/
               1. read lessons.md, finder-kit
                  write plan.md: phases →
                  clusters (1-4 tasks) → gates
               2. review plan (10-item checklist)
 approve  ◄──  report plan + review
   │
   ▼           3. write briefs/<phase>.md
                  exact Edit blocks old → new
                                                  4. preflight.sh
                                                     model · reply · tool call · Finder
 "Chạy" ◄────  AskUserQuestion (runner, model) ◄─ READY
   │
   ▼                                              5. dispatch.sh --cluster C1  (Bash, background)
                                                     lint: sections · placeholders ·
                                                     Edit blocks match the code ── ✗ → exit 3 (0 tokens)
                                                     preflight stamp ─────────── ✗ → exit 5
                                                     baseline T0 (measured)
                                                     run ─────────────────────────────► apply Edit blocks (1 call each)
                                                                                         Verify (1 shell call per task)
                                                                                         log once · or [?] and stop
                                                     watchdogs: start hang / stall
                                                     plan edited? ── yes → exit 6 BRIEF_TAMPERED
                                                     new [?] ?    ── yes → exit 4 ASK ──┐
                                                     gate (--check)                     │
                                                     review package → reviews/          │
                                                     ledger row → ledger.md             │
               ◄──── ONE wake-up per cluster: read result lines only ◄──────────────────┘
               6. decide:
                  ASK  → code fact: answer · product decision: ask YOU ──► answers.md → resume
                  GATE red → fix brief → resume (2×) → stronger model → Claude finishes
                  DONE → write ruling if any → next cluster (resume)
               7. phase end: full verify once (tail), grade the code,
                  root cause plan/worker/kit → lessons.md
 report  ◄──── what works · gates · grade · ledger (who did what)
   │
   ▼  /clear → fresh session → ws.sh status → next phase
```

## Numbers measured on 2026-10-25 (real runs)

| | v5 | v6 |
|---|---|---|
| Worker steps for the same cluster | 15 | 5 |
| Worker input tokens for it | 104k | 39k |
| Claude turns for the selftest | 15 | 7 |
| Claude tokens re-read per turn (long session) | ~600k | ~600k → ~30-60k with a fresh session per phase |

## v7 (designed, not built): parallel lanes per phase

```
 phase N plan ──► lane A (worktree A) ─┐
                  lane B (worktree B) ─┼─► integration worktree: merge (git 3-way → re-apply Edit blocks
                                       │   → integrator vua/glm-5.3 → Claude/you)
                                       └─► ONE phase gate ── green → back up your tree → apply → next phase
                                                         └─ red → failing files → that lane fixes → re-gate
```
