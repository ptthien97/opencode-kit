# User Requirements

Status: APPROVED
Approval evidence: User selected “Approve (Recommended)” in the requirement intake.

## USER_INTENT

Upgrade the existing `~/.pi/tools/tavily-key-pool` so Pi/Tavily MCP can use multiple API keys reliably and automatically fail over when the current key is invalid, out of quota, or rate-limited.

## CURRENT_PROBLEM

- The key pool exists but Pi is not configured to use it.
- Tavily MCP points directly to `https://mcp.tavily.com/mcp/` and currently fails to connect with HTTP 405.
- The current proxy rotates keys per HTTP request, which can break MCP session continuity.
- The current failure handling only marks 401/403 responses and does not implement complete 429/quota/`Retry-After` failover.

## EXPECTED_BEHAVIOR

- An MCP session/request chain remains pinned to one key while that key is healthy.
- Authentication, rate-limit, or quota failures move the key to an appropriate invalid/cooldown state and retry with another available key when safe.
- Retries are bounded and API keys are never exposed in logs or errors.
- Pi connects to Tavily through the local proxy and Tavily tools work in a real invocation.

## USERS_AND_CALLERS

- User: Bro.
- Primary caller: Pi MCP gateway.
- Upstream: Tavily remote MCP.

## SCOPE_IN

- Upgrade code in `~/.pi/tools/tavily-key-pool`.
- Improve rotation, sticky routing, failover, and error handling.
- Add/update tests for rotation and proxy behavior.
- Update operational documentation as needed.
- Update `~/.pi/agent/mcp.json` to use the local proxy.
- Start the proxy and verify a real Tavily tool call.

## SCOPE_OUT

- Do not create a second key-pool/MCP project.
- Do not create Tavily accounts or bypass provider quotas.
- Do not share keys with other users.
- Do not automate CAPTCHA/2FA bypass.
- Do not commit or push changes.
- Do not change unrelated MCP servers.

## REQUIREMENTS

- REQ-1: Reuse the existing `tavily-key-pool` project.
- REQ-2: Use sticky key routing rather than blind round-robin per HTTP request.
- REQ-3: Fail over on authentication/authorization failures, rate limits, or quota exhaustion signals.
- REQ-4: Honor cooldown and upstream `Retry-After` when provided.
- REQ-5: Bound retries and do not replay unsafe requests when reliable replay is not possible.
- REQ-6: Redact keys in logs and avoid writing real keys into source, fixtures, or shared config.
- REQ-7: Point Pi Tavily MCP to the local proxy after the upgrade.
- REQ-8: Preserve compatibility with existing commands such as `import-key`, `status`, `next`, and `serve-proxy`.

## CONSTRAINTS

- Only use API keys legitimately controlled by Bro.
- Prefer small changes compatible with the existing SQLite/config structure.
- Back up configuration before changing it.
- Do not print API keys during verification.

## EDGE_CASES

- No active keys.
- All keys are cooling down or invalid.
- Upstream returns 401, 403, 429, 5xx, timeout, or network errors.
- `Retry-After` is present or absent.
- Request body cannot be replayed safely.
- Client provides no clear session identifier.
- Proxy restarts during a session.

## ACCEPTANCE_CRITERIA

- AC-1: Consecutive requests in the same context stay on the same key while it remains healthy.
- AC-2: A failover-eligible error switches to another key and succeeds when another valid key is available.
- AC-3: A 429 response cools down the key using `Retry-After` or the configured fallback.
- AC-4: Exhausted keys produce a clear redacted error without looping.
- AC-5: New rotation/proxy tests pass.
- AC-6: Pi connects to Tavily through the local proxy and successfully invokes at least one real Tavily tool.
- AC-7: Existing CLI commands continue to work.

## VERIFICATION_EXPECTATIONS

- Run the TypeScript/test suite for `tavily-key-pool`.
- Test failover with a mock/local upstream to avoid unnecessary quota use.
- Validate JSON configuration.
- Start the local proxy, reconnect Tavily MCP, and invoke one tool.
- Confirm no real key appears in logs or diffs.

## RISKS

- Tavily remote MCP may require a different transport or authentication format than the current proxy.
- Replaying MCP requests must avoid duplicating non-idempotent work.
- Multi-account/key usage must comply with Tavily terms.

## OPEN_DECISIONS

- (none)
