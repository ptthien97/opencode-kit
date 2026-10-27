# Baseline management report template

Use this structure as the default. Section titles may be adapted slightly, but every report must retain the nine essential management sections (or bilingual equivalents below).

## Mandatory headings (aliases)

| Key | English | Vietnamese |
|---|---|---|
| title | (document H1 title) | (tiêu đề H1) |
| executive_summary | Executive Summary | Tóm tắt điều hành |
| scope_and_period | Scope and Reporting Period | Phạm vi và kỳ báo cáo |
| key_work_and_results | Key Work and Results | Công việc và kết quả chính |
| verifiable_evidence | Verifiable Evidence | Bằng chứng có thể kiểm chứng |
| status_assessment | Status Assessment | Đánh giá trạng thái |
| risks_and_blockers | Risks and Blockers | Rủi ro và trở ngại |
| recommendations_or_next_steps | Recommendations or Next Steps | Kiến nghị hoặc bước tiếp theo |
| sources_and_appendix | Sources and Appendix | Nguồn và phụ lục |

Alternate English acceptances:

- Scope / Reporting Period
- Key Results
- Evidence
- Status
- Risks
- Recommendations / Next Steps
- Sources / Appendix / Limitations

Alternate Vietnamese acceptances:

- Tóm tắt
- Phạm vi / Kỳ báo cáo
- Kết quả chính
- Bằng chứng
- Trạng thái
- Rủi ro
- Kiến nghị / Bước tiếp theo
- Nguồn / Phụ lục / Hạn chế

## Suggested Markdown skeleton (English)

```markdown
# <Report title>

| Field | Value |
|------|-------|
| Report date | YYYY-MM-DD |
| Author | ... |
| Reader | ... |
| Period | YYYY-MM-DD → YYYY-MM-DD |
| Repository / branch | ... |
| Scope | ... |

## Executive Summary

- Fact: ... (Evidence: E1)
- Analysis: ...

## Scope and Reporting Period

...

## Key Work and Results

1. Fact: ... (E1, E2)
2. Analysis: ...

## Verifiable Evidence

| ID | Type | Reference | Summary | Paths / notes |
|----|------|-----------|---------|---------------|
| E1 | commit | a1b2c3d | ... | path/a, path/b |

## Status Assessment

- Fact: ...
- Limitation: ...

## Risks and Blockers

- ...

## Recommendations or Next Steps

- Recommendation: ...

## Sources and Appendix

- Git range: ...
- Limitations: ...
```

## Suggested Markdown skeleton (Vietnamese)

```markdown
# <Tiêu đề báo cáo>

| Trường | Giá trị |
|--------|---------|
| Ngày báo cáo | YYYY-MM-DD |
| Người lập | ... |
| Người nhận | ... |
| Kỳ báo cáo | YYYY-MM-DD → YYYY-MM-DD |
| Kho mã / nhánh | ... |
| Phạm vi | ... |

## Tóm tắt điều hành

- Sự kiện: ... (Bằng chứng: E1)
- Phân tích: ...

## Phạm vi và kỳ báo cáo

...

## Công việc và kết quả chính

1. Sự kiện: ... (E1)
2. Phân tích: ...

## Bằng chứng có thể kiểm chứng

| Mã | Loại | Tham chiếu | Tóm tắt | Đường dẫn / ghi chú |
|----|------|------------|---------|---------------------|
| E1 | commit | a1b2c3d | ... | ... |

## Đánh giá trạng thái

- Sự kiện: ...
- Hạn chế: ...

## Rủi ro và trở ngại

- ...

## Kiến nghị hoặc bước tiếp theo

- Kiến nghị: ...

## Nguồn và phụ lục

- Phạm vi Git: ...
- Hạn chế: ...
```

## Writing guidance

- Keep the executive summary short (5–8 bullets or one short paragraph + bullets)
- Prefer outcomes (“payment validation is covered by automated checks”) over internals (“added `validateInvoice()` in `service.py`”)
- Evidence section should be a table or compact list—not pasted diffs
- Status must not over-claim; use limitations liberally when proof is thin
- One to two pages is ideal for weekly status; expand only when the reader asks
