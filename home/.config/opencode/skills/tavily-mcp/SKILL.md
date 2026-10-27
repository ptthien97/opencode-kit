---
name: tavily-mcp
description: |
  Web search, content extraction, crawling, URL discovery, and deep research via the Tavily MCP server. Use this skill whenever the user wants to search the web, find articles, research a topic, look something up online, extract content from a URL, grab text from a webpage, crawl documentation, download a site's pages, discover URLs on a domain, or conduct in-depth research with citations. Also use when they say "search for", "look up", "find me", "what's the latest on", "fetch this page", "get the page at https://", or reference extracting data from external websites. Do NOT trigger for local file operations, git commands, deployments, or code editing tasks.
---

# Tavily via MCP

Web search, content extraction, site crawling, URL discovery, and deep research through the `tavily` MCP server. Results come back as structured JSON in the tool response — no shell, no API key handling, no JSON parsing needed.

## Prerequisites

The `tavily` MCP server must be configured (global `~/.config/opencode/opencode.json` or project `.mcp.json`/`opencode.json`) with a Tavily API key. Tool names follow the pattern `<server>_<tool>`, so with server name `tavily` the tools are:

| Tool | Purpose |
|------|---------|
| `tavily_tavily_search` | Find pages / answer questions (no specific URL yet) |
| `tavily_tavily_extract` | Pull content from specific URLs |
| `tavily_tavily_map` | Discover URLs on a site (structure discovery) |
| `tavily_tavily_crawl` | Bulk-extract many pages from a site |
| `tavily_tavily_research` | Deep multi-source research with citations |

If a tool is missing, the server may be named differently — check the actual tool names available in the session and use those.

## Workflow

Follow this escalation pattern — start simple, escalate when needed:

1. **Search** — No specific URL. Find pages, answer questions, discover sources.
2. **Extract** — Have a URL. Pull its content directly.
3. **Map** — Large site, need to find the right page. Discover URLs first.
4. **Crawl** — Need bulk content from an entire site section.
5. **Research** — Need comprehensive, multi-source analysis with citations.

| Need | Tool | When |
|------|------|------|
| Find pages on a topic | `tavily_tavily_search` | No specific URL yet |
| Get a page's content | `tavily_tavily_extract` | Have a URL |
| Find URLs within a site | `tavily_tavily_map` | Need to locate a specific subpage |
| Bulk extract a site section | `tavily_tavily_crawl` | Need many pages (e.g., all `/docs/`) |
| Deep research with citations | `tavily_tavily_research` | Need multi-source synthesis |

For detailed parameter reference, use the individual skill for each tool (e.g., `tavily-search`, `tavily-crawl`).

## Tips

- **Keep queries under 400 characters** — think search query, not prompt.
- **MCP returns results directly in context** — you do not need `--json`, files, or pipes. Every result is already structured.
- **Beware `include_raw_content: true` on search** — full page text enters your context. Prefer snippets first, then `tavily_tavily_extract` on chosen URLs.
- **`tavily_tavily_research` is synchronous** and takes 30-120s — tell the user it will take a while before calling it.
- **News/finance topics are CLI-only** — the MCP search tool only supports `topic: general`. Use `time_range` instead for recency.
