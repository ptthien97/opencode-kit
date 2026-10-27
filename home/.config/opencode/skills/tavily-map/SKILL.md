---
name: tavily-map
description: |
  Discover and list all URLs on a website without extracting content, via the Tavily MCP server (tavily_tavily_map tool). Use this skill when the user wants to find a specific page on a large site, list all URLs, see the site structure, find where something is on a domain, or says "map the site", "find the URL for", "what pages are on", "list all pages", or "site structure". Faster than crawling — returns URLs only. Essential when you know the site but not the exact page. Combine with extract for targeted content retrieval.
---

# tavily map (MCP)

Discover URLs on a website without extracting content. Faster than crawling.

## When to use

- You need to find a specific subpage on a large site
- You want a list of all URLs before deciding what to extract or crawl
- Step 3 in the [workflow](../tavily-mcp/SKILL.md): search → extract → **map** → crawl → research

## How to call

Use the MCP tool `tavily_tavily_map` with these arguments:

| Argument | Description |
|----------|-------------|
| `url` | Root URL to begin mapping (required) |
| `max_depth` | Levels deep (1-5, default: 1) |
| `max_breadth` | Links per page (default: 20) |
| `limit` | Max URLs to discover (default: 50) |
| `instructions` | Natural language guidance for URL filtering |
| `select_paths` | Regex patterns of paths to include (e.g. `/blog/.*`) |
| `select_domains` | Regex patterns of domains to include |
| `allow_external` | Whether to include external links (default: true) |

## Map + Extract pattern

Use map to find the right page, then extract it. This is often more efficient than crawling an entire site:

1. **Step 1:** `tavily_tavily_map` with `url: "https://docs.example.com"`, `instructions: "authentication"`
2. **Step 2:** `tavily_tavily_extract` on the specific URL you found

## Tips

- **Map is URL discovery only** — no content extraction. Use extract or crawl for content.
- **Map + extract beats crawl** when you only need a few specific pages from a large site.
- **Use `instructions`** for semantic filtering when path patterns aren't enough.

## See also

- [tavily-extract](../tavily-extract/SKILL.md) — extract content from URLs you discover
- [tavily-crawl](../tavily-crawl/SKILL.md) — bulk extract when you need many pages
