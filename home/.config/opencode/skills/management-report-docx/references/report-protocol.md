# Management report protocol

## Purpose

Turn reviewed repository and Git evidence into a concise management-facing Word report without inventing outcomes or dumping implementation detail.

## Evidence-first order

1. Frame objective, reader, scope, period, language
2. Collect read-only evidence inside scope
3. Sanitize and bound evidence
4. Classify each claim as fact / analysis / recommendation
5. Draft structured content
6. Render `.docx` and validate structure

## Git and source inspection (REQ-3, REQ-4)

Default commands (adjust range to the request):

```bash
git rev-parse --is-inside-work-tree
git status -sb
git log --since=<start> --until=<end> --pretty=format:'%h %ad %an %s' --date=short
git log --since=<start> --until=<end> --stat --pretty=format:'%h %s'
git diff --stat <range>
```

Optional when user explicitly includes uncommitted work:

```bash
git status --porcelain
git diff --stat
git diff --cached --stat
```

Rules:

- Prefer short hashes and file-path summaries over full patches
- If commit messages disagree with the diff, trust the diff and note the mismatch
- Multi-author / multi-branch scopes: group by theme, not by raw commit list only
- Never execute repository application code to “prove” behavior

## Claim labeling (REQ-6, REQ-7)

| Label | Use when | Report presentation |
|---|---|---|
| Fact | Directly supported by commit, path, doc, or verification output | Cite evidence id/hash/path |
| Analysis / inference | Reasonable interpretation beyond the raw artifact | Prefix with “Analysis:” / “Phân tích:” |
| Recommendation | Suggested next action | Prefix with “Recommendation:” / “Kiến nghị:” |
| Gap / conflict | Missing or contradictory evidence | Explicit “Limitation:” / “Hạn chế:” callout |

Forbidden without evidence: “completed,” “tested,” “released,” quantified business impact, production rollout claims.

## Sanitization (REQ-9)

Redact or omit:

- API keys, bearer tokens, passwords, private keys, connection strings
- `.env` values and credential filenames’ secret contents
- Long raw diffs, full logs, large binary listings
- Unnecessary private absolute paths (prefer repo-relative paths)

Size bounds (defaults used by CLI):

- Single text field: 4_000 characters after sanitize
- Evidence detail cell: 500 characters
- Diff excerpt: 20 lines max, otherwise replace with summary

## Output naming (REQ-10)

```
management-report-YYYY-MM-DD.docx
management-report-YYYY-MM-DD-<scope-slug>.docx
```

Write to a user-visible directory (`./reports/` recommended). Always report the absolute path.

## JSON input contract (`render --input`)

```json
{
  "language": "vi",
  "title": "Báo cáo tiến độ tuần 29/2026",
  "metadata": {
    "reportDate": "2026-07-20",
    "author": "Team Alpha",
    "reader": "Giám sát dự án",
    "periodStart": "2026-07-13",
    "periodEnd": "2026-07-20",
    "repository": "example/app",
    "branch": "main",
    "scope": "Thanh toán và báo cáo"
  },
  "executiveSummary": [
    {"kind": "fact", "text": "...", "evidenceIds": ["E1"]}
  ],
  "scopeAndPeriod": "Phạm vi: ... Kỳ báo cáo: ...",
  "keyWorkAndResults": [
    {"kind": "fact", "text": "...", "evidenceIds": ["E1", "E2"]},
    {"kind": "analysis", "text": "..."}
  ],
  "evidence": [
    {
      "id": "E1",
      "type": "commit",
      "reference": "a1b2c3d",
      "summary": "Bổ sung xác thực thanh toán",
      "paths": ["src/payments/service.py", "tests/test_payments.py"]
    }
  ],
  "statusAssessment": [
    {"kind": "fact", "text": "...", "evidenceIds": ["E1"]},
    {"kind": "gap", "text": "Chưa có bằng chứng triển khai production."}
  ],
  "risksAndBlockers": [
    {"kind": "analysis", "text": "..."}
  ],
  "recommendationsOrNextSteps": [
    {"kind": "recommendation", "text": "..."}
  ],
  "sourcesAndAppendix": [
    "Git log main 2026-07-13..2026-07-20",
    "Limitation: commit messages incomplete for a1b2c3d"
  ],
  "limitations": [
    "Không có bằng chứng kiểm thử tự động cho nhánh feature X."
  ]
}
```

`kind` values: `fact` | `analysis` | `recommendation` | `gap`.

## Markdown input contract (`render --markdown`)

Markdown must include headings that map to mandatory sections (EN or VI). See `report-template.md`.

## Renderer selection

1. If system `pandoc` is available and executable → convert Markdown (generated from JSON or provided) to DOCX
2. Else → skill-owned minimal OOXML writer (Python standard library only)
3. Never auto-install Pandoc or Python packages

## Validation gates (AC-8)

A document passes when:

1. File is a ZIP containing `[Content_Types].xml` and `word/document.xml`
2. `word/document.xml` parses as XML
3. All mandatory section headings are present (EN or VI aliases)
4. Sanitizer finds no high-confidence secret patterns in extracted text (soft fail reported; hard fail for private-key blocks)

## Edge-case handling

| Edge | Required behavior |
|---|---|
| Little/no Git history | Disclose; rely on files/docs if any; mark confidence low |
| Misleading commit messages | Prefer diff/path evidence; note mismatch |
| Unspecified period | State assumed range (e.g. last 7 days / since last tag) |
| Uncommitted changes | Exclude unless requested; if included, label as worktree |
| Conflicting evidence | Surface conflict; do not pick a silent winner |
| Mixed commit | Split themes in narrative; one evidence row may list multiple paths |
| No business impact evidence | Do not invent impact; put gap in limitations |
| Multi-repo/author | Separate subsections; keep one evidence table with scope column if needed |
| DOCX tooling failure | Prefer fallback renderer; if both fail, stop with clear error (no partial silent success) |
