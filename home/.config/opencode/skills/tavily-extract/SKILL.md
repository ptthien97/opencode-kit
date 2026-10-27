---
name: tavily-extract
description: |
  Extract clean markdown or text content from specific URLs via the Tavily MCP server (tavily_tavily_extract tool). Use this skill when the user has one or more URLs and wants their content, says "extract", "grab the content from", "pull the text from", "get the page at", "read this webpage", or needs clean text from web pages. Handles JavaScript-rendered pages, returns LLM-optimized markdown, and supports query-focused reranking. Can process up to 20 URLs in a single call.
---

# tavily extract (MCP)

Extract clean markdown or text content from one or more URLs.

## When to use

- You have a specific URL and want its content
- You need text from JavaScript-rendered pages
- Step 2 in the [workflow](../tavily-mcp/SKILL.md): search → **extract** → map → crawl → research

## How to call

Use the MCP tool `tavily_tavily_extract` with these arguments:

| Argument | Description |
|----------|-------------|
| `urls` | List of URLs (required, max 20 per call) |
| `query` | Rerank chunks by relevance to this query |
| `extract_depth` | `basic` (default) or `advanced` (JS-heavy pages) |
| `format` | `markdown` (default) or `text` |
| `include_images` | Include image URLs |

## Extract depth

| Depth | When to use |
|-------|-------------|
| `basic` | Simple pages, fast — try this first |
| `advanced` | JS-rendered SPAs, dynamic content, tables |

## Tips

- **Max 20 URLs per request** — batch larger lists into multiple calls.
- **Use `query`** to get only content relevant to a topic instead of full pages.
- **Try `basic` first**, fall back to `advanced` if content is missing.
- **Skip extract when search already returned what you need** — if a search result snippet is enough, don't fetch the page.
- Results return directly in the tool response — no `--json`, no file output.

## See also

- [tavily-search](../tavily-search/SKILL.md) — find pages when you don't have a URL
- [tavily-crawl](../tavily-crawl/SKILL.md) — extract content from many pages on a site
