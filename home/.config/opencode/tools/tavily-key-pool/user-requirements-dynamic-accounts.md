# User Requirements — Dynamic Tavily Accounts

Status: APPROVED
Approval evidence: User selected “Approve (Recommended)” in requirement intake.

## USER_INTENT

Replace the fixed ten-slot Tavily account list with a dynamic account registry managed entirely in SQLite.

## CURRENT_PROBLEM

- `config.yaml` declares fixed `acc01…acc10` slots.
- Login/logout menus show slots that were never created.
- Adding an account depends on YAML rather than dynamic creation.
- Bro currently has five real accounts that must be preserved while empty placeholders are removed.

## EXPECTED_BEHAVIOR

- SQLite is the source of truth for accounts.
- Migration keeps accounts with keys or real data and removes empty `pending` placeholders created from YAML.
- `tavilylogin` lists existing accounts plus `Add new account` and `Cancel`.
- Adding an account generates the next `accNN` ID, validates the hidden key, and persists only after validation.
- `tavilylogout` confirms, then removes the key, affinities, and complete account record.
- Rotation/proxy read accounts from SQLite rather than `config.accounts`.

## USERS_AND_CALLERS

- Bro through `tavilylogin` and `tavilylogout`.
- Tavily MCP proxy through SQLite.
- Existing CLI commands such as `status`, `next`, `fetch`, and `fetch-all`.

## SCOPE_IN

- Move account registry ownership to SQLite.
- Safely migrate the current database.
- Remove the fixed ten-account sample list from runtime config.
- Update login/logout, rotation, fetch, status, tests, and docs.
- Preserve the five current real accounts.

## SCOPE_OUT

- Do not change sticky routing/failover.
- Do not revoke keys at Tavily.
- Do not create Google/Tavily accounts.
- Do not change hidden key input or key format.
- Do not commit/push.
- Do not delete accounts with keys during migration.

## REQUIREMENTS

- REQ-1: SQLite is the only account registry source after migration.
- REQ-2: YAML no longer requires an `accounts` list.
- REQ-3: Migration preserves accounts with keys/real data and removes empty pending placeholders.
- REQ-4: `tavilylogin` offers `Add new account`.
- REQ-5: New IDs use `accNN`, with the highest existing numeric ID plus one.
- REQ-6: Invalid keys never create an account record.
- REQ-7: Confirmed logout deletes the full account record and affinity.
- REQ-8: Rotation selects active accounts from SQLite only.
- REQ-9: Status/menu display only existing SQLite accounts.
- REQ-10: CLI behavior no longer depends on ten hard-coded accounts.
- REQ-11: Keys remain absent from argv, output, and logs.
- REQ-12: The proxy continues working after restart with the migrated schema.

## CONSTRAINTS

- Back up database and config before migration.
- Migration is idempotent.
- Never remove a record whose `api_key` is non-null.
- Preserve IDs of the five current accounts.
- Legacy YAML accounts may seed/migrate once but must not recreate placeholders afterward.

## EDGE_CASES

- Empty database.
- Only YAML-created placeholders.
- Numeric ID gaps.
- Non-`accNN` IDs.
- Invalid key for a new account.
- Logout of a sticky account or the last account.
- No active keys.
- Migration runs more than once.

## ACCEPTANCE_CRITERIA

- AC-1: Five real accounts keep their IDs and keys.
- AC-2: Empty pending placeholders disappear.
- AC-3: Config does not require ten accounts.
- AC-4: Login lists existing accounts and `Add new account`.
- AC-5: Adding after `acc05` creates `acc06`.
- AC-6: Invalid input creates no record.
- AC-7: Confirmed logout removes the account and affinity completely.
- AC-8: Rotation/proxy use active SQLite accounts only.
- AC-9: No active key returns a clear bounded error.
- AC-10: Typecheck and tests pass.
- AC-11: Global commands work from any directory.
- AC-12: Restarted proxy completes MCP handshake.

## VERIFICATION_EXPECTATIONS

- Back up and inspect redacted record counts/states before migration.
- Test migration from ten placeholders plus five real accounts.
- Test next-ID creation, invalid input, logout deletion, and cancellation.
- Run `npm run typecheck` and `npm test`.
- Restart proxy and verify MCP handshake.
- Check logs for raw-key leakage.

## RISKS

- The old constructor recreated placeholders from YAML; migration must distinguish empty records accurately.
- The currently running proxy must be restarted after the code update.
- Local account deletion does not revoke a Tavily key.

## OPEN_DECISIONS

- (none)
