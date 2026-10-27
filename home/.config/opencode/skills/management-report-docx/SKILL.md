---
name: management-report-docx
description: "Produce simple, evidence-based management-facing Microsoft Word (.docx) progress/status reports from repository evidence and Git history. Use when the user wants a supervisor/management report, work summary DOCX, progress report for leadership, or a non-technical Word summary of completed work grounded in commits and source changes."
version: "1.0.0"
---

# management-report-docx

Create a clean, professional Microsoft Word (`.docx`) management report grounded in reviewed evidence—especially Git history and source artifacts—while avoiding unnecessary technical detail.

## When to use

- Progress, status, review, or summary reports for a supervisor/manager
- Translating repository work (commits, diffs, tests, docs) into management language
- Exporting an editable `.docx` with traceable evidence and explicit limitations

## When not to use

- Google Docs or PDF export (out of scope for v1)
- BI dashboards or complex analytics
- Mutating the repository (commit, push, reset, rewrite history, clean)
- Executing project code or untrusted scripts just to gather evidence

## Required workflow (agent)

Always follow this order. **Review evidence before drafting prose.**

### 1. Frame the report

Confirm or infer:

| Field | Guidance |
|---|---|
| Objective | What decision or update does the reader need? |
| Reader | Manager / supervisor / stakeholder (non-technical default) |
| Scope | Repo, package, feature, author, branch |
| Period | Dates or commit range; if missing, state the default used |
| Language | Match the user request (Vietnamese primary; English supported) |

### 2. Collect evidence (read-only)

For repository reports, inspect **only** within the requested scope:

1. Git history: `git log`, shortstat, subject/body for the range
2. Changed paths: names and high-level purpose (not long raw diffs)
3. Tests / docs / config / release notes when relevant
4. Uncommitted worktree **only if the user explicitly asks**
5. External web research **only if requested or truly necessary**; cite sources

Do **not**: run project code, install packages, commit/push, or rewrite history.

### 3. Sanitize evidence

Before any prose or export:

- Redact secrets, tokens, credentials, private keys, and sensitive config values
- Prefer relative paths; avoid leaking private absolute home paths when unnecessary
- Cap oversized diffs/logs; summarize instead of embedding raw dumps
- Use the skill sanitizer when preparing structured input (see CLI)

### 4. Translate to management language

Map technical facts into:

1. Work completed (what changed for the product/process)
2. Outcomes / value (only when evidence supports it)
3. Current status (in progress / done / blocked—only with evidence)
4. Risks and blockers
5. Next steps and recommendations

**Label clearly:**

- **Fact** — directly supported by evidence (cite commit/path/doc)
- **Analysis / inference** — reasoned interpretation
- **Recommendation** — suggested action

Never invent figures, business impact, test completion, or release status. If evidence is missing or conflicting, **disclose** it.

### 5. Draft structure

Adapt section order/titles to the request, but **retain these essential sections**:

1. Title and report metadata
2. Executive summary
3. Scope and reporting period
4. Key work and results
5. Verifiable evidence
6. Status assessment
7. Risks and blockers
8. Recommendations or next steps
9. Sources and appendix (when useful)

See `references/report-template.md` for the baseline form and bilingual heading keys.

### 6. Generate the `.docx`

Prefer the skill-owned CLI (stdlib + optional system Pandoc; **never** auto-install deps):

```bash
# From structured JSON (recommended)
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py render \
  --input /path/to/report.json \
  --output /path/to/reports/management-report-YYYY-MM-DD.docx

# From prepared Markdown
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py render \
  --markdown /path/to/report.md \
  --output /path/to/reports/management-report-YYYY-MM-DD.docx

# Validate package + mandatory headings
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py validate \
  --docx /path/to/reports/management-report-YYYY-MM-DD.docx
```

**Output path rules (REQ-10):**

- Clear name including report date, e.g. `management-report-2026-07-20.docx`
- Write to an explicit, easy-to-find path (prefer project `./reports/` or the path the user named)
- Always tell the user the absolute output path

### 7. Self-check the document

Before handing off:

- [ ] Opens as a valid Word package (ZIP/OOXML)
- [ ] Contains mandatory management sections
- [ ] Evidence table/list has traceable refs (hashes, paths, docs, verification)
- [ ] Narrative is manager-readable (no class/function dump)
- [ ] No secrets, long raw diffs, or unsupported factual claims
- [ ] Missing/conflicting evidence is visible

## CLI reference

```bash
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py self-check
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py render --input report.json --output out.docx
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py render --markdown report.md --output out.docx
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py validate --docx out.docx
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py sanitize --text "..."
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py sample --output /tmp/sample-management-report.docx
```

JSON schema for `--input` is documented in `references/report-protocol.md`.

## Progressive disclosure

| File | Purpose |
|---|---|
| `references/report-protocol.md` | Evidence rules, labeling, sanitization, JSON contract |
| `references/report-template.md` | Baseline headings (EN/VI) and section guidance |
| `scripts/report_docx.py` | Renderer (Pandoc or stdlib OOXML), validator, sanitizer |
| `scripts/test_report_docx.py` | Contract tests |

## Example: source code + Git history → management report

User request (Vietnamese):

> Lập báo cáo quản lý tuần này về thay đổi trên nhánh `main` từ 2026-07-13 đến 2026-07-20, xuất file Word.

Agent steps (abbreviated):

1. Frame: progress report for supervisor; period 2026-07-13..2026-07-20; language VI.
2. Evidence (read-only):
   - `git log --since=2026-07-13 --until=2026-07-20 --oneline --no-merges`
   - `git log --since=... --stat` (summarize; do not paste huge diffs)
   - skim changed docs/tests for outcome language
3. Sanitize: strip tokens; summarize file lists.
4. Draft JSON with facts citing short hashes, analysis labeled, gaps disclosed.
5. Render:

```bash
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py render \
  --input ./reports/week-report.json \
  --output ./reports/management-report-2026-07-20.docx
python3 ~/.claude/skills/management-report-docx/scripts/report_docx.py validate \
  --docx ./reports/management-report-2026-07-20.docx
```

6. Reply with absolute path and a short verbal summary; do not claim production release unless evidence exists.

## Hard rules

- Evidence before prose
- Management language; minimal implementation detail
- Facts vs analysis vs recommendations must stay distinct
- Disclose missing/conflicting evidence
- Redact sensitive data; no oversized raw dumps
- No Git mutation; no auto package install
- Do not claim completed / tested / released without evidence
