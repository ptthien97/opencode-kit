---
name: google-drive-mcp
description: Google Drive, Docs, Sheets, Slides via MCP (stdio). List/search/upload/download, folders, Shared Drives. Requires Google Cloud OAuth Desktop client and one-time browser auth.
---

# Google Drive MCP (Claude Code)

## MCP server

- **Name:** configure the MCP server as `google-drive` in Claude Code
- **Package:** `@piotr-agier/google-drive-mcp` (stdio via `npx`, same pattern as `playwright` / `context7`)
- **After config changes:** restart or reconnect Claude Code, then verify that the `google-drive` MCP tools/resources are available

## What you get

- **Tools:** file/folder CRUD, search, upload/download, Docs/Sheets/Slides edits, Calendar (if scopes enabled)
- **Resources:** Drive files exposed as MCP resources for read workflows
- **Multi-account:** optional `account` parameter on tools when multiple Google accounts are linked

For **read-only** search + `gdrive://` resources only, swap the package to `@modelcontextprotocol/server-gdrive` and use scope `drive.readonly` (see [Official read-only](#official-read-only-alternative) below).

## One-time Google Cloud setup

1. [Create a project](https://console.cloud.google.com/projectcreate) and enable APIs:
   - Google Drive API (required)
   - Google Docs / Sheets / Slides / Calendar APIs (optional; enable what you need)
2. **OAuth consent screen** → External or Internal; add your Google account as a **test user** while app is in Testing.
3. **Credentials** → Create **OAuth client ID** → type **Desktop app** (not Web).
4. Download JSON → save as:

   ```text
   ~/.config/google-drive-mcp/gcp-oauth.keys.json
   ```

   ```bash
   mkdir -p ~/.config/google-drive-mcp
   # move downloaded client JSON to gcp-oauth.keys.json
   ```

5. **Scopes (Data Access):** start with the set you need. Broader scopes need re-auth after changes (`GOOGLE_DRIVE_MCP_SCOPES` or consent screen). Common aliases: `drive`, `drive.readonly`, `drive.file`, `documents`, `spreadsheets`, `presentations`.

**Never commit** `gcp-oauth.keys.json` or `tokens.json` to git.

## Authenticate (browser)

Pi cannot complete OAuth for you. Run once in a terminal:

```bash
npx -y @piotr-agier/google-drive-mcp auth
```

- Opens browser on `127.0.0.1` (ports 3000–3004 by default).
- Tokens saved to `~/.config/google-drive-mcp/tokens.json` (mode 0600).
- If ports clash with a dev server: `export GOOGLE_DRIVE_MCP_AUTH_PORT=3100` before `auth`.

Then `/reload` Pi and call Drive tools via `mcp({ tool: "<tool_name>", args: "..." })` or direct MCP tools if `directTools` is on.

## Pi `mcp.json` entry

Already wired under `google-drive` when this skill is installed. Optional env overrides:

| Variable | Purpose |
|----------|---------|
| `GOOGLE_DRIVE_OAUTH_CREDENTIALS` | Path to `gcp-oauth.keys.json` if not in `~/.config/google-drive-mcp/` |
| `GOOGLE_DRIVE_MCP_TOKEN_PATH` | Custom token file path |
| `GOOGLE_DRIVE_MCP_SCOPES` | Comma-separated scope aliases (forces re-auth if changed) |
| `GOOGLE_DRIVE_MCP_AUTH_PORT` | First port for OAuth callback loopback |

## When to use

- Find or organize files/folders in Drive from the agent
- Read or export Doc/Sheet content into the session (prefer MCP + targeted reads; avoid dumping huge files into chat)
- Upload/download project artifacts to a known folder path (e.g. `/Work/Projects/...`)
- Shared Drive operations when the OAuth user has access

## Agent workflow

1. Confirm `google-drive` is connected (`mcp` status or list tools).
2. **Search/list** before guessing file IDs.
3. **Download/read** only the slice needed; use Claude Code `Read` or focused `Bash` processing for large local exports and return only relevant summaries.
4. **Upload/create** with explicit folder paths and names; confirm Shared Drive vs My Drive when relevant.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Server fails on start | Keys missing: place `gcp-oauth.keys.json` under `~/.config/google-drive-mcp/` or set `GOOGLE_DRIVE_OAUTH_CREDENTIALS` |
| `redirect_uri_mismatch` | OAuth client must be **Desktop app**; Web clients need every `http://127.0.0.1:<port>/oauth2callback` registered |
| Tools time out / 401 | Re-run `npx @piotr-agier/google-drive-mcp auth`; Testing-mode refresh tokens expire after ~7 days (Google policy) |
| Scope errors | Update consent + `GOOGLE_DRIVE_MCP_SCOPES`, delete `tokens.json`, auth again |

## Official read-only alternative

Lightweight MCP reference server (search + read resources only):

```json
"google-drive-readonly": {
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-gdrive"],
  "env": {},
  "directTools": true,
  "idleTimeout": 0
}
```

Auth: place `gcp-oauth.keys.json` in the server working directory or follow package README; run `npx -y @modelcontextprotocol/server-gdrive auth` if supported by installed version. Scope: `https://www.googleapis.com/auth/drive.readonly`.

## Google-hosted HTTP MCP (advanced)

URL: `https://drivemcp.googleapis.com/mcp/v1` — **does not** support dynamic client registration. You must create OAuth client ID/secret in Google Cloud and configure HTTP MCP + OAuth in a client that supports it (see Hermes/Craft docs). Pi `mcp.json` HTTP entries work for static URLs but OAuth for this endpoint is not the same as the stdio `npx` flow above; prefer stdio unless you already operate OAuth for that endpoint.

## Security

- Treat Drive content as sensitive; do not paste secrets from files into repos.
- Use narrow scopes (`drive.file` / `readonly`) when full `drive` is not required.
- Revoke access in [Google Account → Third-party access](https://myaccount.google.com/permissions) if tokens are compromised.