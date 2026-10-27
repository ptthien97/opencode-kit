# Implementation Plan

Status: SEALED
Requirements: REQ-1 through REQ-8
Acceptance criteria: AC-1 through AC-7
Workflow: OSF Verified

## Stage 1 — Configuration and persistent state

Files:
- `src/config.ts`
- `src/store.ts`
- `config.example.yaml`

Changes:
1. Add backward-compatible proxy defaults for bounded failover, request body limits, session affinity TTL, authentication mode, and quota cooldown.
2. Add explicit store operations for authentication invalidation, rate-limit/quota cooldown, transient failure tracking, success reset, and cooldown expiry.
3. Add a SQLite `session_affinity` table so MCP session-to-account bindings survive proxy restarts without storing API keys in the mapping.
4. Preserve existing `markFailure`, CLI, and database behavior where compatibility is required.

Verification:
- Existing databases open without migration errors.
- Existing config without new keys loads with safe defaults.

## Stage 2 — Sticky selection and safe failover

Files:
- `src/rotate.ts`
- `src/proxy.ts`

Changes:
1. Extend key selection with optional preferred account and exclusion sets while keeping `getNextApiKey(store, cfg)` compatible.
2. Resolve affinity from `mcp-session-id` and Tavily attribution/session headers; bind upstream session IDs returned by initialize responses.
3. Inject Tavily credentials securely, preferring a Bearer header while retaining configurable query compatibility.
4. Buffer incoming replayable request bodies with a configured size bound.
5. Retry only explicit rejection responses (`401`, `403`, `429`) where upstream has rejected the request; do not replay ambiguous network failures or `5xx` responses.
6. Honor `Retry-After`, apply longer quota cooldown when quota/credit exhaustion is detected, exclude attempted accounts, and cap attempts.
7. Stream successful upstream responses, including long-lived SSE, instead of buffering them.
8. Sanitize local errors and redact all logged keys.

Verification:
- Same MCP session remains pinned to one account.
- 429/401/403 can move to a different account within the attempt bound.
- SSE-compatible responses stream through the proxy.

## Stage 3 — Automated tests and documentation

Files:
- `test/all.ts`
- `README.md`
- `IMPLEMENTATION.md`
- `package.json` if a typecheck script is useful

Changes:
1. Replace the remote-dependent proxy test with a deterministic local mock upstream.
2. Test sticky affinity, 429 failover, `Retry-After` cooldown, exhausted-key behavior, key redaction, and existing round-robin/CLI behavior.
3. Update docs to describe sticky sessions, bounded failover, local Pi configuration, and operational limitations.

Verification:
- `npm test` passes without real Tavily quota use.
- TypeScript typecheck passes.

## Stage 4 — Pi integration and live verification

Files:
- `~/.tavily-key-pool/config.yaml`
- `~/.pi/agent/mcp.json`
- timestamped backups under `~/.pi/agent/backups/` and `~/.tavily-key-pool/backups/`

Changes:
1. Back up both runtime configuration files before editing.
2. Add normalized proxy settings to the private Tavily pool config without exposing stored keys.
3. Point only the `tavily` MCP server at `http://127.0.0.1:8765/tavily/mcp/` and remove direct upstream credentials from that entry.
4. Start the local proxy, reconnect Pi's Tavily MCP server, and call one Tavily tool.

Verification:
- JSON/YAML configuration parses.
- Local proxy is listening only on `127.0.0.1`.
- Tavily MCP connects and exposes tools.
- At least one real tool call succeeds if the configured pool contains a valid active key.

## Stop conditions

- Stop rather than replay on network errors, timeouts, or ambiguous `5xx` responses.
- Stop live verification if all configured keys are invalid/test placeholders; report the blocker without asking for or printing secrets.
- Stop and request an approved amendment if implementation evidence requires behavior outside REQ-1 through REQ-8.
