<!-- finder-kit-skill-v3 -->
# Tracking contract — shared `workflow-track` rules

Every leaf skill follows these rules. Only the role-specific event kinds differ;
each `SKILL.md` states its own in one line.

## Wire shape

`workflow-track` takes one `request` object. `action` is one of `start`,
`update_run`, `upsert_task`, `append_event`, `finish`, `get`. Every action
carries `run_id`; every mutation except `start` also carries
`expected_revision` from the previous response.

```yaml
start:        { action: start, run_id: <id>, title: <text>,
                mode: full_loop | standalone, current_phase: discover | frame | plan | execute | verify | review,
                harness: <harness name>, initial_tasks: [<task>] }
update_run:   { action: update_run, run_id: <id>, expected_revision: <n>,
                update: { state?, current_phase?, pinned? } }
upsert_task:  { action: upsert_task, run_id: <id>, expected_revision: <n>,
                current_phase?: <phase>, task: <task contract v2> }
append_event: { action: append_event, run_id: <id>, expected_revision: <n>,
                event: { phase, kind, actor_role, summary,
                         task_id?, citations?, command?: { command, result }, command_result? } }
finish:       { action: finish, run_id: <id>, expected_revision: <n>,
                final_state: completed | failed | blocked }
get:          { action: get, run_id: <id> }
```

- `kind` is `started | note | command | failure | verification | decision`.
- `actor_role` is `planner | implementer | verifier | reviewer | system`.
- `finish` takes `final_state`, not `state`. The MCP tool has no `cancel`
  action; cancellation lives on the HTTP control surface.
- Unlisted fields are accepted and silently dropped, so a misspelled field
  produces an empty record instead of an error. Use only the names above.

## Cadence

- **Start or join once**, at the beginning of the run: one `start` for a fresh
  run, or one `update_run` carrying this leaf's `current_phase` when joining.
- **Write on state change, failure, or verification** — not on progress.
- **No spam:** no per-token, per-thought, or per-step heartbeat events, and no
  reasoning dumps in `summary`.
- **Finish once**, with `final_state`. When joining a full-loop run in which
  this leaf's phase is not terminal, do not finish; the router owns the run
  lifecycle.

## Join an existing run

1. Do not call `start`. Call `update_run` with this leaf's `current_phase`.
2. Treat `run_id` as untrusted: call `get` first. If the run does not load,
   report it and stop; never start a replacement run.
3. `start` on an existing run id is rejected. On a revision conflict, reload
   with `get` and retry once with the current revision.
4. Prefer evidence supplied by the upstream phase; query `finder` only for
   citations still marked `unknown`.

## Tracking is non-blocking

When `workflow-track` errors, times out, returns 401/403, or the workspace is
not approved: continue the real work and publish the outcome from real
evidence. Never derive a phase `state` from tracking success, and never retry
the same call in a tight loop.
