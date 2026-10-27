---
name: tavily-search
description: |
  Search the web with LLM-optimized results via the Tavily MCP server (tavily_tavily_search tool). Use this skill when the user wants to search the web, find articles, look up information, get recent news, discover sources, or says "search for", "find me", "look up", "what's the latest on", "find articles about", or needs current information from the internet. Returns relevant results with content snippets, relevance scores, and metadata — optimized for LLM consumption. Supports domain filtering, time ranges, and multiple search depths.
---

# tavily search (MCP)

Web search returning LLM-optimized results with content snippets and relevance scores.

## When to use

- You need to find information on any topic
- You don't have a specific URL yet
- First step in the [workflow](../tavily-mcp/SKILL.md): **search** → extract → map → crawl → research

## How to call

Use the MCP tool `tavily_tavily_search` with these arguments:

| Argument | Description |
|----------|-------------|
| `query` | Search query (required, keep under 400 chars) |
| `max_results` | Max results, 0-20 (default: 5) |
| `search_depth` | `ultra-fast`, `fast`, `basic` (default), `advanced` |
| `time_range` | `day`, `week`, `month`, `year` |
| `start_date` / `end_date` | Results in a date window (YYYY-MM-DD) |
| `include_domains` / `exclude_domains` | Domain whitelist / blacklist |
| `country` | Boost results from a country |
| `include_raw_content` | Include full page text in results |
| `include_images` / `include_image_descriptions` | Image results |
| `exact_match` | Only results containing exact phrases |

## Search depth

| Depth | Speed | Relevance | Best for |
|-------|-------|-----------|----------|
| `ultra-fast` | Fastest | Lower | Real-time chat, autocomplete |
| `fast` | Fast | Good | Need chunks, latency matters |
| `basic` | Medium | High | General-purpose (default) |
| `advanced` | Slower | Highest | Precision, specific facts |

## CLI → MCP notes

- `--topic news/finance` and `--include-answer` are **CLI-only**; the MCP tool supports only `topic: general`. Use `time_range` for recency.
- Results are returned directly in the tool response — no `--json`, no parsing.

## Tips

- **Break complex queries into sub-queries** for better results.
- **Use `include_raw_content` sparingly** — full pages flood your context. Prefer snippets, then `tavily_tavily_extract` on chosen URLs.
- **Use `include_domains`** to focus on trusted sources.
- **Use `time_range`** for recent information.

## See also

- [tavily-extract](../tavily-extract/SKILL.md) — extract content from specific URLs
- [tavily-research](../tavily-research/SKILL.md) — comprehensive multi-source research
