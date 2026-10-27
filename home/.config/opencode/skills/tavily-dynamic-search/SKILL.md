---
name: tavily-dynamic-search
description: |
  Programmatic web search with context hygiene. Use this skill for any research task where you need to search the web, filter results, and extract specific information — without flooding your context window with raw HTML and boilerplate. This is the default skill for web research. Triggered by "search for", "look up", "find", "research", "what's the latest on", or any query that requires current web information. Also use when asked to "search and filter", "find the important parts", or "extract the key details" — any case where the user wants curated, noise-free content.
---

# Tavily dynamic search (MCP)

Search the web, filter results, and extract content so **raw page data never floods your context window**. Only the relevant parts you decide to keep come back.

## Why this matters

A search with `include_raw_content: true` can return 8 results × 30-50K chars each = **~300K characters** of raw page content. If that all enters your context, you burn tokens reading navigation bars, cookie banners, and boilerplate — and reasoning quality degrades under the noise.

**MCP already helps:** the tool response is the only thing that enters context (no shell output, no files, no JSON parsing). But you still control what you request. The filtering logic is yours — you decide what matters for each query.

## Core rule

**NEVER use `include_raw_content: true` on a broad search.** Start with snippets only, then drill into specific pages with `tavily_tavily_extract`.

```text
# WRONG — raw page content floods your context
tavily_tavily_search(query="solid-state battery commercialization 2026",
                     include_raw_content=true, max_results=8)

# RIGHT — snippets first, decide, then extract
tavily_tavily_search(query="solid-state battery commercialization 2026",
                     max_results=8)
# -> pick 2-3 promising URLs from titles/snippets/scores
tavily_tavily_extract(urls=["https://source1.com/article", "https://source2.com/report"],
                      query="commercialization timeline")
```

## How to search

Two building blocks, compose them however the query demands:

**`tavily_tavily_search`** — returns titles, URLs, snippets, scores. The triage step.

**`tavily_tavily_extract`** — fetches full page content for specific URLs you chose. The drill-in step.

### Single turn

When you know upfront what you're looking for: search, then extract the best 1-3 results. Specific factual queries, known keywords.

### Multi-turn iteration

For open-ended research you need to **explore before you extract** — same principle as Programmatic Tool Calling: search, see titles, decide which results to drill into, then extract.

**Turn 1 — search and triage:** run `tavily_tavily_search` from multiple angles (use `include_domains`, `time_range`, different phrasings), dedupe by URL, keep titles + snippets + scores. Print a short ranked list in your reply so the user sees progress, then pick the top candidates.

**Turn 2 — targeted extraction:** call `tavily_tavily_extract` on only the chosen URLs, with `query` set to your topic so only relevant chunks return.

**Turn 3 (optional) — chase leads:** if turn 2 revealed new URLs or subtopics, search or extract specifically for them.

## Writing your filtering (applied to tool args)

**Triage first.** Inspect titles and scores before fetching full pages. Don't extract everything blindly.

**Be specific.** A financial query should extract with `query: "revenue earnings guidance"`. A technical query should target `query: "API reference"`. Match the extract `query` to what you need.

**Limit extraction.** Prefer `tavily_tavily_extract` over `include_raw_content` — extract with a `query` returns only the relevant chunks.

**Token budget awareness.** Your final synthesis is what the user reads. Target 150-600 tokens per source. If you're passing 5000+ chars from a single page into your reply, you're probably not filtering enough. But if a source has a critical data table, it's fine to keep more.

## Options cheat sheet

### tavily_tavily_search

| Argument | Use for |
|----------|---------|
| `max_results` | Number of results (default: 5, max: 20) |
| `search_depth` | `ultra-fast`, `fast`, `basic` (default), `advanced` |
| `time_range` | `day`, `week`, `month`, `year` |
| `include_domains` / `exclude_domains` | Whitelist / blacklist domains |
| `country` | Boost results from a country |
| `exact_match` | Only results containing exact phrases |

### tavily_tavily_extract

| Argument | Use for |
|----------|---------|
| `urls` | List of URLs (max 20) |
| `query` | Rerank chunks by relevance to your topic |
| `extract_depth` | `basic` (default) or `advanced` (JS-heavy pages) |
| `format` | `markdown` (default) or `text` |

## Notes

- News/finance `topic` is CLI-only; via MCP use `time_range` for recency.
- `include_raw_content` on search still exists and is occasionally right — e.g. when you need one specific page's full text and will not call extract again. Use it sparingly and with `max_results` small.
