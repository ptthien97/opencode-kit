# Implementation Plan — Tavily Login/Logout Commands

Status: SEALED
Requirements: REQ-1 through REQ-9
Acceptance criteria: AC-1 through AC-8
Workflow: OSF Verified

## Stage 1 — Store and secure interaction helpers

Files:
- `src/store.ts`
- new `src/interactive.ts`

Changes:
1. Add `removeKey(accountId)` as a transactional store operation that clears the key, timestamps/use state, failures, cooldown, sets `pending`, and deletes affinity.
2. Implement account display/selection in configuration order.
3. Implement hidden TTY input using raw mode; support non-TTY stdin for deterministic tests without printing input.
4. Validate the full key against `tavily.key_regex` and configured account IDs.
5. Implement explicit confirmation with safe cancellation defaults.

## Stage 2 — CLI and global entry points

Files:
- `cli.ts`
- `package.json`
- `~/.local/bin/tavilylogin`
- `~/.local/bin/tavilylogout`

Changes:
1. Add `interactive-login` and `interactive-logout` CLI commands while preserving existing commands.
2. Ensure interactive login reads the key from stdin/TTY rather than argv.
3. Add package scripts for local testing/convenience.
4. Create thin executable shell launchers that resolve the single implementation under `~/.pi/tools/tavily-key-pool` and forward environment/stdin.

## Stage 3 — Tests and documentation

Files:
- `test/all.ts`
- `README.md`

Changes:
1. Add store tests for key removal, pending state, field reset, and affinity cleanup.
2. Spawn interactive CLI commands with piped stdin for valid import, invalid key, confirmed logout, and cancelled logout.
3. Document global commands, hidden input, local-only deletion, and PATH requirement.

## Stage 4 — Verification

1. Run `npm run typecheck` and `npm test`.
2. Confirm both launchers are executable and discoverable via `command -v`.
3. Run both launchers against an isolated test config from a directory outside the project.
4. Confirm the production proxy remains listening on `127.0.0.1:8765`.
5. Confirm no raw key appears in command lines or verification logs.
