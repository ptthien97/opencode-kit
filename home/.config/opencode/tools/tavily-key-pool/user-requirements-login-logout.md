# User Requirements — Tavily Login/Logout Commands

Status: APPROVED
Approval evidence: User selected “Approve (Recommended)” in requirement intake.

## USER_INTENT

Create global `tavilylogin` and `tavilylogout` commands for managing keys in the existing Tavily key pool through an account-selection menu.

## CURRENT_PROBLEM

Keys currently require direct `npm run import-key -- accXX ...` or manual tooling. There is no friendly, secure slot-selection flow.

## EXPECTED_BEHAVIOR

- `tavilylogin` lists `acc01…acc10`, status, and redacted keys; lets the user choose one account; reads a Tavily key without echo; validates it; saves it; and activates the slot without putting the key in process arguments or logs.
- `tavilylogout` lists accounts; lets the user select one; requires confirmation; deletes the local key; resets the slot to `pending`; clears failure/cooldown and related session affinity; and does not revoke the key at Tavily.
- Both commands are globally available from `~/.local/bin`.

## USERS_AND_CALLERS

- User: Bro.
- Callers: interactive terminal shells.
- Storage: the existing Tavily key-pool SQLite database.

## SCOPE_IN

- Add safe key deletion to `KeyStore`.
- Add CLI commands or an interactive command flow for login/logout.
- Create `~/.local/bin/tavilylogin` and `~/.local/bin/tavilylogout`.
- Add tests and documentation.
- Verify compatibility with the running proxy.

## SCOPE_OUT

- Do not revoke keys on the Tavily dashboard.
- Do not delete accounts or browser profiles.
- Do not automate Google/Tavily login.
- Do not display raw API keys.
- Do not change the existing rotation/failover behavior.
- Do not commit or push.

## REQUIREMENTS

- REQ-1: `tavilylogin` presents an account-selection menu.
- REQ-2: Keys are read without echo and never passed via command-line arguments.
- REQ-3: Keys must match the configured Tavily key regex.
- REQ-4: Successful import activates the slot and clears old failure/cooldown state.
- REQ-5: `tavilylogout` requires confirmation before deletion.
- REQ-6: Logout removes the raw key from SQLite, sets the slot to `pending`, and clears related affinity.
- REQ-7: Output only shows redacted keys.
- REQ-8: Commands work from any directory when `~/.local/bin` is on `PATH`.
- REQ-9: Existing CLI commands remain compatible.

## CONSTRAINTS

- Never expose a key through process arguments, shell history, test logs, or source.
- Reuse `~/.pi/tools/tavily-key-pool`.
- Global executables are thin entry points to one implementation in the project.

## EDGE_CASES

- Invalid account selection.
- Empty or invalid key.
- Logout of an empty/pending slot.
- Cancellation at selection or confirmation.
- Missing config/database.
- Proxy affinity points to a removed key.

## ACCEPTANCE_CRITERIA

- AC-1: `tavilylogin` works from any directory and shows the account menu.
- AC-2: Key input is not echoed or present in process arguments.
- AC-3: A valid key is stored and status shows the account active with a redacted key.
- AC-4: An invalid key is rejected without changing the database.
- AC-5: Confirmed `tavilylogout` removes the key and returns the slot to pending.
- AC-6: Cancelled logout leaves the database unchanged.
- AC-7: Logout clears affinity for the selected account.
- AC-8: Typecheck and tests pass and the proxy remains operational.

## VERIFICATION_EXPECTATIONS

- Test stdin import, invalid key, logout, cancellation, and affinity cleanup.
- Run `npm run typecheck` and `npm test`.
- Exercise both global executables with test configuration and no real key.
- Check executable permissions and `PATH`.

## RISKS

- If `~/.local/bin` is absent from `PATH`, report the required PATH addition without editing unrelated shell config.
- Local deletion does not revoke the key at Tavily.

## OPEN_DECISIONS

- (none)
