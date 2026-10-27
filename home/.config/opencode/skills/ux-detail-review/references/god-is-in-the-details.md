# God Is In The Details - Practical Review Notes

This reference distills Buzz Usborne's detail-first UX perspective into reusable review checks.

## Table of Contents

1. Confirm user actions immediately
2. Match loading behavior to context
3. Remove hostile or misleading interactions
4. Respect platform conventions
5. Use motion to support understanding
6. Treat microcopy as product behavior
7. Review Heuristic Table
8. Severity Mapping Guide

## 1) Confirm user actions immediately

Principle:
- Every meaningful user action should return visible feedback with minimal delay.

Check:
- After click/tap/submit, can users confirm success without reading logs or switching screens?

Common misses:
- Silent button states
- No confirmation after save/add
- Subtle changes outside viewport

Fix patterns:
- Temporary state changes (`Added`, `Saved`)
- Inline confirmations near the action origin
- Progress state for multi-step completion

## 2) Match loading behavior to context

Principle:
- Waiting states should reduce uncertainty, not just fill time.

Check:
- Does loading communicate what is happening and what the user should do next?

Common misses:
- Generic spinner for every task
- No distinction between quick and long waits
- No continuity from previous state

Fix patterns:
- Skeletons for content continuity
- Progress wording for long operations
- Context-specific placeholders (for example list/item/map states)

## 3) Remove hostile or misleading interactions

Principle:
- Do not make users guess what is interactive.

Check:
- Are links, buttons, and drag areas visually and behaviorally consistent?

Common misses:
- Hover-only cues with no focus/active state
- Clickable text styled like static copy
- Non-clickable elements styled like links/buttons

Fix patterns:
- Strong affordance for interactive elements
- Consistent focus/hover/active states
- Explicit disabled states and reasons

## 4) Respect platform conventions

Principle:
- Follow established interaction patterns unless a clear benefit justifies deviation.

Check:
- Does behavior match user expectations on the current platform?

Common misses:
- Hidden scroll behavior or custom controls that break native instincts
- Novel gestures without onboarding
- Primary actions placed in unexpected zones

Fix patterns:
- Prefer native scrolling, keyboard behavior, and touch targets
- Keep primary actions in familiar positions
- Add lightweight cues when introducing custom interaction

## 5) Use motion to support understanding

Principle:
- Motion should explain state change, hierarchy, and causality.

Check:
- Do animations clarify what changed and where it moved?

Common misses:
- Decorative animation with no semantic value
- Abrupt transitions that break user orientation
- Inconsistent easing and duration across similar actions

Fix patterns:
- Motion tied to source and destination elements
- Consistent timing scale
- Reduce motion when user/system preference requires it

## 6) Treat microcopy as product behavior

Principle:
- UI copy is part of interaction quality, not a final cosmetic pass.

Check:
- Do labels, errors, and empty states clearly guide the next action?

Common misses:
- Vague errors ("Something went wrong")
- Blameful tone
- Missing recovery instructions

Fix patterns:
- State what happened, why (if known), and next best action
- Use respectful and concise language
- Add actionable links or fallback choices

## Review Heuristic Table

| Lens | Failure Signal | User Impact | Minimum Fix |
|---|---|---|---|
| Action feedback | User repeats clicks | Doubt, accidental duplication | Immediate visual confirmation |
| Loading behavior | User waits without context | Anxiety, abandonment | Context-aware loading state |
| Interaction honesty | Misread interactive affordances | Errors, backtracking | Consistent affordance language |
| Native conventions | "Why does this work like this?" | Learning overhead | Align to platform default |
| Motion quality | Transition feels random | Lost orientation | Motion mapped to state change |
| Microcopy tone | Error gives no recovery path | Task failure | Clear next-step guidance |

## Severity Mapping Guide

- `P0`: Prevents critical task completion or causes trust break.
- `P1`: Causes significant friction on primary flows.
- `P2`: Degrades confidence or speed but does not block.
- `P3`: Cosmetic or minor polish issue.
