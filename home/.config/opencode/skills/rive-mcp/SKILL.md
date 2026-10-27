---
name: rive-mcp
description: Author and export Rive (.riv/.rev) and Spline scenes via Polymation MCP (rivemcp). Use for creating animations, state machines, keyframes, import/export .riv, and Rive↔Spline conversion—not for generic Lottie (use lottie MCP).
---

# Rive MCP (Polymation / rivemcp)

## MCP server

- **Name:** configure the MCP server as `rive` in Claude Code
- **Command:** `rivemcp` (stdio, `directTools: true`)
- **Package:** `rivemcp@1.8.2` — install globally: `npm install -g rivemcp@1.8.2`
- **Tools:** Rive authoring tools become available after Claude Code reconnects to the server

## License (optional)

- Free trial: **3 exports** per machine fingerprint
- Paid: set `POLYMATION_LICENSE_KEY` or `RIVEMCP_LICENSE_KEY` in env (add under `rive.env` in `mcp.json` if needed)
- Docs: https://polymation.stunning.gg / https://rivemcp.stunning.gg

## When to use

- Generate or edit `.riv` / `.rev` from natural language or structured scene JSON
- State machines, view models, physics/prefabs via HLAPI
- Load existing `.riv`, modify, re-export with validation
- Rive ↔ Spline conversion (when using those tool categories)

## When not to use

- **Lottie** search/fetch JSON → `/skill:lottie-mcp` (`lottie` MCP, `@saastemly/lottie-mcp`)
- **Official Rive Editor** live MCP (Early Access app) — separate product; not this server
- **Rive docs only** → Context7 or `rive-docs-mcp` (npm `rive-docs-mcp`, not installed by default)

## Troubleshooting

1. `rivemcp: command not found` → `npm install -g rivemcp@1.8.2` and ensure `/opt/homebrew/bin` (or the npm global bin) is on Claude Code's `PATH`
2. First `npx -y rivemcp` may download native binary — prefer global install to avoid slow cold start
3. After changing MCP configuration, restart or reconnect Claude Code and verify that the `rive` tools are available

## Verify

```bash
which rivemcp && rivemcp --version
timeout 3 rivemcp  # should print free-trial banner, not "command not found"
```