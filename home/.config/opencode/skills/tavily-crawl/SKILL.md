---
name: tavily-crawl
description: |
  Crawl websites and extract content from multiple pages via the Tavily MCP server (tavily_tavily_crawl tool). Use this skill when the user wants to crawl a site, download documentation, extract an entire docs section, bulk-extract pages, or says "crawl", "get all the pages", "download the docs", "extract everything under /docs", "bulk extract", or needs content from many pages on the same domain. Supports depth/breadth control, path filtering, and semantic instructions.
---

# tavily crawl (MCP)

Crawl a website and extract content from multiple pages.

## When to use

- You need content from many pages on a site (e.g., all `/docs/`)
- You want to download documentation for offline use
- Step 4 in the [workflow](../tavily-mcp/SKILL.md): search → extract → map → **crawl** → research

## How to call

Use the MCP tool `tavily_tavily_crawl` with these arguments:

| Argument | Description |
|----------|-------------|
| `url` | Root URL to begin the crawl (required) |
| `max_depth` | Levels deep (1-5, default: 1) |
| `max_breadth` | Links per page (default: 20) |
| `limit` | Total pages cap (default: 50) |
| `instructions` | Natural language guidance for semantic focus |
| `select_paths` | Regex patterns of paths to include (e.g. `/docs/.*`) |
| `select_domains` | Regex patterns of domains to include |
| `allow_external` | Whether to include external links (default: true) |
| `extract_depth` | `basic` (default) or `advanced` |
| `format` | `markdown` (default) or `text` |

## Crawl for context vs. data collection

**For agentic use** (feeding results to the LLM):

Always use `instructions` — returns only relevant content instead of full pages, preventing context explosion.

**For data collection** (wanting full pages saved to disk):

The MCP tool returns content in the response — it does not write files. If the user wants markdown files saved locally, write the returned content to files yourself after the call, or ask the user how they want the output stored.

## Tips

- **Start conservative** — `max_depth: 1`, `limit: 20` — and scale up.
- **Use `select_paths`** to focus on the section you need.
- **Use map first** to understand site structure before a full crawl.
- **Always set `limit`** to prevent runaway crawls.
- **Don't call crawl when you only need 1-3 pages** — use `tavily_tavily_extract` instead.

## See also

- [tavily-map](../tavily-map/SKILL.md) — discover URLs before deciding to crawl
- [tavily-extract](../tavily-extract/SKILL.md) — extract individual pages
- [tavily-search](../tavily-search/SKILL.md) — find pages when you don't have a URL
