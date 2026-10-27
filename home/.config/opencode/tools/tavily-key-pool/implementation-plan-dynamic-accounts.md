# Implementation Plan — Dynamic Tavily Accounts

Status: SEALED
Requirements: REQ-1 through REQ-12
Acceptance criteria: AC-1 through AC-12
Workflow: OSF Verified

## Stage 1 — SQLite registry and idempotent migration

Files:
- `src/config.ts`
- `src/store.ts`

Changes:
1. Make legacy YAML `accounts` optional and stop using it as the live registry.
2. Add schema metadata to run an idempotent one-time cleanup of empty pending records created by the old YAML seeding behavior.
3. Stop inserting configured accounts on every `KeyStore` construction.
4. Add dynamic store operations: create/import an arbitrary validated account, calculate next `accNN`, and transactionally delete an account plus affinity.
5. Sort records naturally by numeric `accNN`, with nonstandard IDs after numeric IDs.

## Stage 2 — Remove runtime config dependencies

Files:
- `src/rotate.ts`
- `src/fetch.ts`
- `src/interactive.ts`
- `cli.ts`

Changes:
1. Rotate directly over active SQLite rows; retain optional configured weights by account ID.
2. Validate browser `login`/`fetch` targets against SQLite accounts.
3. Make `fetch-all` iterate SQLite accounts and use stored email metadata only.
4. Make interactive login list real accounts and offer `Add new account`; validate key before persisting the generated ID.
5. Make logout delete the complete account record after confirmation.
6. Make legacy `import-key` create/update the requested account for compatibility.

## Stage 3 — Configuration, tests, and docs

Files:
- `config.example.yaml`
- `test/all.ts`
- `README.md`
- `IMPLEMENTATION.md`

Changes:
1. Remove the fixed account list from example/runtime config.
2. Add migration tests representing five keyed accounts plus five pending placeholders.
3. Update tests for next-ID behavior, invalid add, full deletion, cancellation, dynamic rotation, and empty-pool errors.
4. Update docs to explain SQLite ownership and dynamic account lifecycle.

## Stage 4 — Production migration and verification

1. Back up `keys.db` (including WAL/SHM as applicable) and `config.yaml`.
2. Stop the old proxy before database migration.
3. Update private config to remove the ten-account block.
4. Open the database with new code, verifying five keyed accounts remain and five placeholders are deleted without printing keys.
5. Run typecheck/tests and global launcher tests.
6. Restart proxy and verify MCP initialize/list-tools handshake.
7. Confirm logs contain only redacted keys.
