# Tavily API key pool

Automates **fetch**, **storage**, and **round-robin rotation** of a dynamic set of Tavily API keys. Designed for Pi / local scripts calling Tavily.

## Recommended architecture (multiple Google accounts)

### Why not an Arc extension only?

| Approach | Verdict |
|----------|---------|
| **Arc MV3 extension** | Arc has **no public API** to switch profiles or drive multiple Google sessions. Extensions run in **one** profile at a time. Good as **assist UI** (copy key on current tab), bad for unattended multi-account fetch. |
| **Playwright + persistent Chromium profiles** | **Recommended.** One `userDataDir` per account → isolated cookies/Google session. Login once per account (`login` command, headed). Then headless `fetch` can scrape dashboard. |
| **Arc for humans, Chromium for bots** | Practical split: keep using Arc daily; automation uses `~/.tavily-key-pool/profiles/*` (Chromium). Keys are identical once logged into Tavily. |

### Arc mapping (optional semi-manual)

If Bro insists on Arc for first-time login:

1. Create one Arc Space/Profile per Google account.
2. In each profile: sign in Google → open `https://app.tavily.com/home` → copy the key.
3. Run `tavilylogin`, select **Add new account**, and paste the key with hidden input.

Full unattended refresh → still use **Playwright profiles** (re-login when session expires).

## Components

```
tavily-key-pool/
├── config.example.yaml    # selectors, rotation, proxy; accounts live in SQLite
├── src/
│   ├── store.ts           # SQLite + redacted logs
│   ├── fetch.ts           # Playwright scrape per profile
│   ├── rotate.ts          # get_next_api_key()
│   └── proxy.ts           # optional local HTTP injector
├── arc-extension/         # optional MV3 assist (current tab only)
└── cli.ts                 # login | fetch-all | refresh | status | serve-proxy
```

## Per-account flow

1. `pnpm login acc01` — opens **headed** Chromium with `profiles/acc01/`, Bro completes Google + Tavily once.
2. `pnpm fetch acc01` — headless navigate `tavily.dashboard_url`, extract key via selectors, save `account_id`, `email?`, `api_key`, `last_fetched_at`, `status`.
3. `pnpm fetch-all` — sequential fetch with delay (avoid burst / CAPTCHA).

## Rotation and failover

- `getNextApiKey()` remains round-robin/weighted for new sessions and scripts.
- The MCP proxy is **sticky by session**: it pins `mcp-session-id`, `X-Session-Id`, or `X-Human-Id` to one account while the key is healthy.
- Explicit upstream rejection (`401`, `403`, `429`, `432`) can fail over to another active key, bounded by `proxy.max_failover_attempts`.
- `429` honors `Retry-After`; quota/credit exhaustion uses `proxy.quota_cooldown_seconds` when no retry time is supplied. With `rotation.quota_reset_day` set (day of month credits reset), a `432` quota rejection puts the key in cooldown **until the next reset boundary** instead of a fixed timer — the key is not reused until credits are back.
- Network failures and ambiguous `5xx` responses are **not replayed**, avoiding duplicate non-idempotent work.
- Successful responses are streamed, so Streamable HTTP/SSE remains usable.
- Config: `rotation.*` controls key availability; `proxy.*` controls affinity, auth injection, body replay limit, and failover.

## Operations

| Command | Purpose |
|---------|---------|
| `tavilylogin` | Choose an existing account or dynamically add the next `accNN` |
| `tavilylogout` | Confirm and delete the selected local account record |
| `tavilyquota` | Show plan, used/remaining credits, percentage, and endpoint breakdown for every key |
| `login <id>` | Browser session bootstrap for Playwright fetching |
| `fetch-all` | Bulk initial fetch |
| `refresh --on-error` | Re-fetch accounts with recent 401 |
| `status` | Table with `acc01 … active last=… key=tvly-…XXXX` |
| `serve-proxy` | HTTP forwarder injecting rotated key |

## Global key login/logout

Accounts are stored dynamically in SQLite; there is no fixed account list in YAML. The installers live at:

```text
~/.local/bin/tavilylogin
~/.local/bin/tavilylogout
~/.local/bin/tavilyquota
```

Use them from any directory:

```bash
tavilylogin   # choose an existing account or Add new account
tavilylogout  # choose an account, confirm, delete the local account record
tavilyquota   # check credit quota for every account
```

`~/.local/bin` must be present in `PATH`. New IDs are generated as `accNN` using the highest existing numeric ID plus one. `tavilylogout` does **not** revoke the key on Tavily's dashboard; it removes the complete local SQLite account record and clears related session affinity.

`tavilyquota` calls Tavily's official `GET /usage` endpoint. It does not consume search credits or mutate rotation status. It reports unauthorized, rate-limited, timeout, and network states without exposing keys.

For automation/tests, login/logout use `interactive-login` and `interactive-logout`; non-TTY stdin is accepted but should not be used with real keys in shell command text.

## Secure storage

- DB: `~/.tavily-key-pool/keys.db` (chmod 600), **gitignored**.
- Optional: `TAVILY_POOL_MASTER_KEY` for AES at rest (skeleton uses SQLite + filesystem perms; extend with `better-sqlite3` + encryption).
- **Never** commit `config.yaml` with keys — only `config.example.yaml`.

## Risks

| Risk | Mitigation |
|------|------------|
| **Google / Tavily ToS** | Automation for **your own** accounts; no credential sharing. Prefer official API + rotation over scraping in production. |
| **CAPTCHA / Google block** | Headed `login`, delays between accounts, residential IP, avoid headless on first login. |
| **2FA** | `login` is **manual** — script waits for Bro to finish 2FA. |
| **DOM changes** | Configurable `selectors` in YAML; fail with screenshot to `~/.tavily-key-pool/debug/`. |
| **Key leak in logs** | `redactKey()` everywhere; status shows last 4 chars only. |

## Pi integration

After pool is populated:

```json
"tavily": {
  "type": "http",
  "url": "http://127.0.0.1:8765/tavily/mcp/",
  "directTools": true
}
```

Run `npm run serve-proxy`. The proxy forwards to Tavily's remote MCP endpoint and injects the selected key using `proxy.auth_mode` (`query` by default, matching Tavily's documented remote-MCP URL).

Recommended private config additions in `~/.tavily-key-pool/config.yaml`:

```yaml
proxy:
  bind: 127.0.0.1
  port: 8765
  upstream_mcp_base: https://mcp.tavily.com/mcp/
  auth_mode: query
  max_failover_attempts: 3
  max_request_body_bytes: 1048576
  session_affinity_ttl_seconds: 86400
  quota_cooldown_seconds: 3600
```

Verification:

```bash
npm run typecheck
npm test
npm run status  # keys are always redacted
```