# UX Detail Review

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that delivers detail-level UX reviews focused on the moments where users hesitate, mistrust, or lose flow.

This skill is based on Buzz Usborne's article ["God is in the details"](https://buzzusborne.medium.com/god-is-in-the-details-bc3a9a9a5d88), which outlines practical UX principles for polishing the last 1% of product experience.

## 6-Lens Audit

Every review runs through six lenses:

| Lens | What it checks |
|---|---|
| **Action feedback** | Every user action has immediate, visible confirmation |
| **Loading behavior** | Waiting states match task context and user intent |
| **Interaction honesty** | No deceptive or hostile interaction patterns |
| **Native conventions** | Alignment with platform expectations and learned patterns |
| **Motion quality** | Transitions and micro-animations serve clarity, not decoration |
| **Microcopy tone** | Labels, hints, errors, and empty states are clear and respectful |

## Severity Scale

- `P0` — Critical blocker or trust break
- `P1` — Major friction in core journey
- `P2` — Moderate friction or polish gap
- `P3` — Minor refinement

## Installation

```bash
npx skills add simply-strong-lab/ux-detail-review
```

## Usage

Provide a screenshot, prototype, or URL and ask for a review:

```
UX 리뷰해줘
```
```
Review this UI for usability issues
```
```
디자인 디테일 점검해줘
```

The skill outputs a structured report with prioritized findings, a critical path walkthrough, quick wins, and a validation plan.

## Project Structure

```
├── SKILL.md                          # Skill definition and workflow
├── assets/
│   └── review-template.md            # Output report template
├── references/
│   └── god-is-in-the-details.md      # Core review checklist
└── agents/
    └── openai.yaml                   # OpenAI agent interface config
```

## License

MIT
