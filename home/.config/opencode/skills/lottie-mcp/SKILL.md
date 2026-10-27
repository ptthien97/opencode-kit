---
name: lottie-mcp
description: Find, fetch, and save Lottie JSON via MCP (@saastemly/lottie-mcp). Use for loaders, empty states, status icons, and LottieFiles catalog search—not for authoring binary .riv (use rive-mcp) or building Lottie from scratch in-editor.
---

# Lottie MCP (Claude Code)

## MCP server

- **Name:** configure the MCP server as `lottie` in Claude Code
- **Package:** `@saastemly/lottie-mcp@1.0.1` (stdio via `npx`, Node ≥20)
- **Tools:** names appear with the configured `lottie` server prefix after Claude Code reconnects
- **Network:** Bundled set works **offline**; `*_online` tools need internet (LottieFiles API, local cache on download)

```json
"lottie": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@saastemly/lottie-mcp@1.0.1"],
  "env": {},
  "directTools": true,
  "idleTimeout": 0
}
```

## When to use

| Need | Use Lottie MCP? |
|------|-----------------|
| Spinner / loader / checkmark / error icon for app or web | **Yes** — start with bundled `search_lottie` |
| Browse or search LottieFiles (popular, featured, keyword) | **Yes** — `search_lottie_online` / `discover_lottie_online` |
| Save animation JSON into project `assets/` | **Yes** — `get_lottie` with `out_path` + `inline: false` |
| State machine, tap/hover logic, `.riv` export | **No** — `/skill:rive-mcp` |
| Edit vectors/keyframes like After Effects in agent | **Limited** — fetch JSON, then hand-edit file or convert via Rive MCP `import_lottie` / `convert_format` if `rive` is installed |

## Tools (MCP)

| Tool | Purpose |
|------------------------|---------|
| `lottie_search_lottie` | Keyword search **bundled** CC0 set: spinner, dots, bars, pulse, checkmark, cross, … |
| `lottie_list_lottie` | List bundled slugs (optional `query`, `limit`, `offset`) |
| `lottie_get_lottie` | Get Lottie JSON; bundled via `slug`; online via `id` or `url` from search |
| `lottie_search_lottie_online` | Full LottieFiles catalog search → `id`, preview GIF, `json_url` |
| `lottie_discover_lottie_online` | Feeds: `popular`, `featured`, `recent`, `curated` |

### `get_lottie` parameters (important)

- **`slug`** — bundled only (e.g. `spinner`, `checkmark`)
- **`id` / `url`** — from online search results
- **`out_path`** — write JSON to disk; pair with **`inline: false`** to avoid huge chat payloads
- **`color`** — retint **bundled** animations (hex, e.g. `#22c55e`)

Response may include snippets for `lottie-player`, `lottie-react`, `@lottiefiles/dotlottie-react`.

## Workflows

### A — Fast loader (offline)

1. `lottie_search_lottie({ query: "loading spinner", limit: 10 })`
2. Pick a `slug` from results
3. `lottie_get_lottie({ slug: "spinner", color: "#4F46E5", out_path: "<project>/assets/lottie/loader.json", inline: false })`
4. Wire asset in app (Flutter: `lottie` package + `Lottie.asset`; web: `lottie-react` or dotlottie)

### B — Branded animation from LottieFiles

1. `lottie_search_lottie_online({ query: "success check", limit: 5 })`
2. Note `id` or `json_url` from best match; respect per-animation license on LottieFiles
3. `lottie_get_lottie({ id: <id>, out_path: "<project>/assets/lottie/success.json", inline: false })`
4. Commit asset; document license link if required by team policy

### C — Discover inspiration

1. `lottie_discover_lottie_online({ kind: "popular", limit: 20 })`
2. Same as B for chosen animation

### D — “Chỉnh” animation (realistic scope)

This MCP does **not** expose keyframe/shape editors. Practical edits:

- **Retint** bundled: `get_lottie({ slug, color })`
- **Structural edit:** `get_lottie` → save → edit JSON in repo (layers, opacity, timing) with `read`/`edit`, re-validate in app
- **Heavy conversion to Rive:** use MCP `rive` tools `import_lottie` / `convert_format` when installed (lossy; read loss report)

## Input / output examples

**Input (search bundled):**

```json
{ "query": "dots loader", "limit": 5 }
```

**Output (typical):** list of `{ slug, name, category, duration, tags }`

**Input (fetch to project):**

```json
{
  "slug": "checkmark",
  "color": "#16a34a",
  "out_path": "/path/to/app/assets/animations/success.json",
  "inline": false
}
```

**Output:** path confirmation + optional small metadata; full JSON on disk only.

## Flutter (common stack)

After saving under `assets/animations/`:

- Declare in `pubspec.yaml` under `flutter.assets`
- Use package `lottie` (or team standard) with `Lottie.asset('assets/animations/loader.json')`
- Run `flutter analyze` on touched packages

## Licensing

- **Bundled:** CC0 / public domain (no attribution)
- **LottieFiles downloads:** each animation’s license (often Lottie Simple License); do not redistribute bulk catalogs—only project-needed files

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No `lottie_*` tools | `/reload` Pi; confirm `mcp.json` has `lottie` server |
| Server won’t start | `node -v` ≥ 20; `npx -y @saastemly/lottie-mcp@1.0.1` should log `[lottie-mcp] ready` |
| Online search fails | Network/DNS; retry; fall back to bundled `search_lottie` |
| Huge tool output | Always use `out_path` + `inline: false` for `get_lottie` |

## Verify (2 steps)

1. **Terminal:** `timeout 5 npx -y @saastemly/lottie-mcp@1.0.1` → expect `[lottie-mcp] ready — 7 bundled animations + LottieFiles online`
2. **Pi session:** `/reload` → `mcp({ server: "lottie" })` → 5 tools listed; call `lottie_search_lottie` with `query: "spinner"`

## Related skills

- **`rive-mcp`** — author/interactive `.riv`, Lottie→Rive conversion tools on `rive` server
- **`flutter`** — integrate assets and analyze
- **`tavily-search`** — docs/links when MCP result is insufficient