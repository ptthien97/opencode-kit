---
name: deep-code-search
description: Deep code search via the codebase-retrieval MCP with a one-shot prompting recipe that returns complete bodies and full flows. Use when the user asks to find/locate code or an implementation, trace a call flow, analyze impact or callers, or says things like "tìm code", "chỗ nào implement", "where is X", "trace X to Y", "ai gọi hàm X", "impact của X". Do NOT use for pure UI styling questions, plain file edits on known paths, or version-sensitive external API questions.
---

# Deep Code Search via codebase-retrieval

ALWAYS run this recipe before any manual grep/read for code questions:

## 1. Repo-wide discovery — `codebase-retrieval`
- Name exact symbols and demand completeness:
  "Show the COMPLETE body of `X`, where it is defined, and ALL callers with
  file:line references."
- Flows: "Trace the call path from A to B, naming every hop
  (widget/controller → service → client → interceptor) with line numbers."
- Impact: "Which code depends on `X`? List all callers and affected areas."

## 2. Fill missing connectors — `file-retrieval`
- When a snippet is cut or a connector is missing, use `file-retrieval` on
  the known file with `top_k` 6-10:
  "Show the COMPLETE body of `Y` (code AFTER `X`, roughly lines N-M)."
- Batch related asks: "show X and also show Y" — one call, not several.

## 3. Verify before claiming
- Snippets may be incomplete. Read the exact file (returned line ranges)
  before editing or asserting facts.
- Never run broad `rg` in parallel with codebase-retrieval for the same
  question.
