# Phase plan — TOPIC

Repo: REPO_ABSOLUTE_PATH · Branch: BRANCH · Planner: Claude · Date: YYYY-MM-DD

## Goal
WHAT_IS_TRUE_WHEN_ALL_PHASES_ARE_DONE

## Phases

| Phase | Outcome (observable) | Clusters → Gate | Files (exclusive) | Depends on | Parallel group | Runner | Est. | Done by (ledger) | Status |
|---|---|---|---|---|---|---|---|---|---|
| P1 | … | C1 model+test → `flutter test test/a_test.dart`; C2 wiring → `flutter analyze lib/a.dart` | `a.dart`, `a_test.dart` | — | G1 | worker | 20m | | planned |
| P2 | … | C1 → `flutter analyze lib/b.dart` | `b.dart` | — | G1 | worker | 15m | | planned |
| P3 | … | C1 → …; C2 → … | `c.dart` (uses P1's new API) | P1 | G2 | worker | 25m | | planned |
| P4 | design / risky / tiny edit | — | `d.dart` | P3 | — | Claude | 10m | | planned |

Rules for this table:
- **Clusters → Gate**: split each worker phase into clusters of 1-4 tasks that
  together make one testable step; each cluster ends in a Gate (the narrowest
  test/analyze command that proves it). Run cluster → gate → Claude review →
  next cluster. Batch small same-shape edits (same change across files) into
  one cluster.
- **Done by**: filled after each cluster from `worker-ledger.md`, e.g.
  `C1 worker vua/deepseek-v4.1-flash ses_ab12 · C2 Claude (fix)`. Status:
  planned → running → done / blocked / taken back.
- **Files are exclusive**: no file appears in two phases of the same parallel group.
- **Depends on** lists phases whose output this phase reads (new API, renamed
  symbol, generated code). A phase never starts before its dependencies are
  verified by Claude.
- **Parallel group**: phases in one group have no dependency on each other and
  no shared files. Groups run in order (G1 → G2 → …). Default execution is still
  one phase at a time; a group only runs in parallel when the user asks and the
  worktree mode exists.
- **Runner**: `worker` for well-specified typing; `Claude` for design decisions,
  risky areas (auth, payments, data migration, Firebase/Remote Config), shared
  generated files (`*.g.dart`, l10n, `pubspec.yaml`), and edits of a few known lines.
- Each worker phase: ≤ ~8 tasks, 1-3 files per task, ends in a check that proves
  the phase outcome; one brief per phase.

## Shared touchpoints (never inside a worker phase)
`pubspec.yaml`, `pubspec.lock`, generated code, l10n ARB files, route tables,
DI registration files — list the ones this plan needs and who changes them.

## Order of work
1. G1: P1, P2 (sequential by default)
2. Claude verifies G1, updates plan if needed
3. G2: P3
4. Claude: P4
5. Final review + report

## Rulings (decisions made during execution; copied into later briefs)
- none

## Risks / open questions
- …
