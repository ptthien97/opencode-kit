---
name: ux-detail-review
description: Detail-focused UI/UX review workflow based on Buzz Usborne's "God is in the details". Use when reviewing screenshots, prototypes, websites, or apps for interaction polish, usability friction, feedback clarity, loading behavior, microcopy tone, and platform convention fit. Trigger for requests like "UX 리뷰", "UI 피드백", "디자인 검토", "사용성 분석", "인터랙션 개선", "디테일 점검", "UX review", "UI review", "design critique", "usability audit", or "interaction polish".
---

# UX Detail Review

Deliver a detail-level UX review that focuses on moments where users hesitate, mistrust, or lose flow.

## Workflow

1. Capture review context.
- Identify artifact type (screenshot, prototype, live page, app screen).
- Identify target user action (for example: sign up, buy, submit, compare, search).
- Identify constraints (mobile/desktop, locale, accessibility needs, release scope).

2. Run a 6-lens detail audit.
- Action feedback: Verify each user action has immediate, visible confirmation.
- Loading behavior: Check whether waiting states match task context and user intent.
- Interaction honesty: Detect deceptive or hostile interaction patterns.
- Native conventions: Check alignment with platform expectations and learned patterns.
- Motion quality: Review transitions and micro-animations for clarity, not decoration.
- Microcopy tone: Review labels, hints, errors, and empty states for clarity and respect.

3. Record evidence before suggesting fixes.
- Tie each finding to a concrete UI element, state, or path step.
- Describe the current behavior and user impact in one sentence each.
- Avoid abstract opinions that cannot be observed.

4. Prioritize improvements.
- `P0`: Blocks completion, causes likely abandonment, or creates major trust risk.
- `P1`: Significant friction on key journeys.
- `P2`: Noticeable polish gap with moderate user impact.
- `P3`: Nice-to-have refinement.

5. Propose fix + validation per finding.
- Give one concrete change recommendation.
- Define a validation method (usability check, event metric, A/B, or heuristic re-test).
- Prefer fixes that can be implemented in the current release cycle.

## Required Output Shape

Use the structure in `assets/review-template.md`.

Non-negotiables:
- Include severity (`P0` to `P3`) for every finding.
- Include expected user impact and suggested implementation effort.
- If no issues are found, state that explicitly and list residual risk areas.

## Reference Files

- Core principles and checklist: `references/god-is-in-the-details.md`
- Response scaffold: `assets/review-template.md`

Read only the files above unless the user requests deeper expansion.
