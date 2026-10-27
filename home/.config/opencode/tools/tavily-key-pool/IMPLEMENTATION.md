# Implementation plan (step-by-step)

## Phase 0 — Prerequisites (30 min)

1. `cd ~/.pi/tools/tavily-key-pool && npm install`
2. `mkdir -p ~/.tavily-key-pool && cp config.example.yaml ~/.tavily-key-pool/config.yaml`
3. Run `tavilylogin` for each key and choose **Add new account**. Accounts are stored dynamically in SQLite.
4. Open Tavily dashboard in **one** browser → DevTools → update `selectors` + verify `key_regex` matches `tvly-…`.

## Phase 1 — Bootstrap sessions (1–2 h, manual 2FA)

For each dynamically created account:

```bash
npm run login -- acc01
# Headed Chromium: Google sign-in + Tavily (complete 2FA)
# Close window when dashboard shows API key
```

Repeat for all existing SQLite accounts. **Arc:** optional parallel — use an Arc profile for comfort, then add the copied key with `tavilylogin`.

## Phase 2 — Bulk fetch

```bash
npm run fetch-all
npm run status
```

Expect one `active` row per account created with `tavilylogin`. Failures → screenshot in `~/.tavily-key-pool/debug/`, fix selectors, re-`login` if session dead.

## Phase 3 — Rotation + Pi

Terminal A:

```bash
npm run serve-proxy
```

`~/.pi/agent/mcp.json`:

```json
"tavily": {
  "type": "http",
  "url": "http://127.0.0.1:8765/tavily/mcp/",
  "directTools": true,
  "idleTimeout": 0
}
```

`/reload` Pi. New MCP sessions are assigned from the pool; requests carrying the same session identifier stay pinned to the same account.

## Phase 4 — Sticky failover and refresh

- `401/403` invalidates the rejected key and retries another active key within the configured attempt bound.
- `429` places the key in cooldown, honoring `Retry-After` when present.
- Quota/credit exhaustion uses `proxy.quota_cooldown_seconds` when Tavily does not supply a retry time.
- Network errors and `5xx` responses are not replayed because upstream execution may be ambiguous.
- Cron (optional): `0 6 * * * cd ~/.pi/tools/tavily-key-pool && npm run fetch-all`

## Phase 5 — Arc extension (optional)

1. Arc → Extensions → Load unpacked → `arc-extension/`
2. Per Arc profile: Tavily home → click extension → enter `acc0N` → run pasted `import-key` in terminal.

## API for scripts

```bash
npm run next   # or: npx tsx cli.ts next
```

```ts
import { getNextApiKey } from "./src/rotate.js";
```

## Security checklist

- [ ] `chmod 600 ~/.tavily-key-pool/keys.db`
- [ ] No keys in git / chat logs
- [ ] Revoke leaked keys at app.tavily.com
- [ ] launchd for `serve-proxy` only on localhost