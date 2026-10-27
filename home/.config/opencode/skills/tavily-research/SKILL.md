---
name: tavily-research
description: |
  Conduct comprehensive AI-powered research with citations via the Tavily MCP server (tavily_tavily_research tool). Use this skill when the user wants deep research, a detailed report, a comparison, market analysis, literature review, or says "research", "investigate", "analyze in depth", "compare X vs Y", "what does the market look like for", or needs multi-source synthesis with explicit citations. Returns a structured report grounded in web sources. Takes 30-120 seconds. For quick fact-finding, use tavily-search instead.
---

# tavily research (MCP)

AI-powered deep research that gathers sources, analyzes them, and produces a cited report. Takes 30-120 seconds — warn the user before calling.

## When to use

- You need comprehensive, multi-source analysis
- The user wants a comparison, market report, or literature review
- Quick searches aren't enough — you need synthesis with citations
- Step 5 in the [workflow](../tavily-mcp/SKILL.md): search → extract → map → crawl → **research**

## How to call

Use the MCP tool `tavily_tavily_research` with these arguments:

| Argument | Description |
|----------|-------------|
| `input` | The research task (required) |
| `model` | `mini`, `pro`, or `auto` (default) |

## Model selection

| Model | Use for | Speed |
|-------|---------|-------|
| `mini` | Single-topic, targeted research | ~30s |
| `pro` | Comprehensive multi-angle analysis | ~60-120s |
| `auto` | API chooses based on complexity | Varies |

**Rule of thumb:** "What does X do?" → mini. "X vs Y vs Z" or "best way to..." → pro.

## Notes

- **The MCP call is synchronous** — it blocks until the report is ready. There is no streaming or async polling via MCP (those are CLI-only).
- The full cited report returns in the tool response; pass it through to the user, optionally formatted.
- **For quick facts**, use `tavily_tavily_search` instead — research is for deep synthesis.

## See also

- [tavily-search](../tavily-search/SKILL.md) — quick web search for simple lookups
- [tavily-crawl](../tavily-crawl/SKILL.md) — bulk extract from a site for your own analysis
