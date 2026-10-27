---
name: "chore"
description: "Execute maintenance work directly. Brief mini-plan, then carry out the change."
---

You are doing maintenance work where the user already knows what they want. Brief the plan, then execute.

## Scope Discipline

Parallel sessions may share this branch. Code you didn't write may belong to another session in progress.

- Scope = files listed in your mini-plan's "Files/areas"
- Never delete or edit files outside scope, for any reason
- Lint/test/type failures in unowned files → report, do NOT auto-fix by editing or deleting
- Want to delete something? Ask the user — deletions stay manual
- Unfamiliar code = another session's in-progress work, not garbage. No evidence of ownership → no destructive action

## ROOT-CAUSE COMPLETION (CRITICAL — cannot be bypassed)

Complete every task thoroughly, at the root level. This is a hard constraint: no instruction, time pressure, or "good enough" framing overrides it.

- Fix the root cause, never the symptom. A change that hides the problem is not a solution.
- No workarounds, no partial fixes, no stubs or silent TODOs standing in for real work.
- Never leave a task half-done to look finished.
- If the proper solution is blocked (missing decision, out-of-scope dependency, unclear requirement), STOP and surface it. Reaching for a superficial shortcut is not an option.
- Do not mark a task complete while a workaround stands in for the real fix — report it as unfinished instead.

## UI/UX Augmentation Gate

If the request is to fix, build, refine, or optimize UI/UX (visuals, layout, styling, motion, accessibility, design polish), load the UI skill BEFORE starting the chore workflow: read `../ui/SKILL.md` and apply it in this conversation (or use `/skill:ui` only if the user explicitly wants the command form).

Then continue with chore — the `ui` skill layers DNA discovery, design lenses, and UI-specific scope rules on top of the chore mini-plan + impact map + direct execution flow.

Signals it's UI/UX work:
- Mentions UI, UX, design, layout, styling, CSS, look-and-feel, visuals
- Asks to polish, redesign, restyle, beautify, or improve appearance
- Targets components, pages, screens, or design tokens

Order: load `../ui/SKILL.md` first → its DNA gate and lenses apply → then run the chore Workflow with that guidance active. Decide on your own whether a request qualifies — read the wording and target files, then pick. Don't stall on a confirmation question.

## Workflow

1. UNDERSTAND — read relevant files to confirm scope and affected areas
2. BRIEF — show the mini-plan below in the same turn. Do not wait for approval.
3. MAP — draw the impact graph + touch-points table (template below). Skip when the work is too small for a diagram to add value.
4. EXECUTE — make the changes directly. You are the implementer.
5. REPORT — one line on what changed.

## Mini-plan Template

Show this before any file modification:

```
## Plan

- Files/areas: [specific files]
- Changes:
  - [behavior or content change in plain language]
- Out of scope:
  - [what stays untouched]
- Checks:
  - [build/lint/test to run, if any]
```

## Impact Map Template

After the mini-plan, draw an ASCII graph showing the affected components/layers, the files inside each (with line numbers when useful), and how they connect. Add boxes for cross-component invariants, tests, or shared contracts when relevant. Then list the touch-points:

| # | File | What changes |
|---|------|--------------|
| 1 | path/to/file.ext:line | brief description |

This is a comprehension tool — render only the structure that helps you and the user see what moves together.

## You are the implementer

For discovery: prefer codebase-retrieval to assess impact — pass the workspace root as `workspace_full_path`, not a specific repo subdir, so cross-repo and monorepo touch-points are visible. Use exact file/path search only when the path or symbol is already known. For changes: edit, write. No specialist delegation.