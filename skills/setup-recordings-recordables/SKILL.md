---
name: setup-recordings-recordables
description: Set up or extend a Rails Recording/Recordable delegated-type architecture with Bucket ownership, tree hierarchy, events, concern-based behavior, and override hooks. Use when adding new recordables, wiring Recording concerns, implementing event tracking/timeline behavior, or documenting/testing this model pattern.
---

# Setup Recordings Recordables

Implement the Recording/Recordable pattern as a repeatable workflow. Keep Recordables immutable and place shared behavior on Recording + concerns.

## Reference Files

Load these first before editing:
- `references/recording-and-recordable-implementation.md`
- `references/event-model-implementation.md`

## Workflow

1. Confirm scope and target files.
- Determine whether work is:
  - initial setup,
  - adding a new recordable type,
  - extending concerns/overrides, or
  - documentation + tests only.

2. Wire core model relationships.
- Ensure `Bucket` owns many recordings.
- Ensure `Recording` belongs to `Bucket` (through `Bucketable`).
- Ensure `Recording` uses delegated type with approved `RECORDABLE_TYPES`.
- Ensure each recordable includes `Recordable`.

3. Implement or verify Recording concern stack.
- Keep behavior on Recording concerns: `Bucketable`, `Tree`, `Discardable`, `Eventable`, `Timeline`, `Commenter`, `Counter`, `Publisher`, `Broadcaster`, `Searcher`, `Permissible`.
- Validate callback interactions:
  - create/update events,
  - discard hooks and cascading,
  - counter/search/broadcast updates.

4. Implement or verify Event integration.
- Ensure `Event` is bucket-scoped and immutable.
- Ensure `Eventable` contract methods are implemented in `Recording`.
- Ensure timeline rendering falls back cleanly when specialized event partials are missing.

5. Implement or verify Recordable override behavior.
- Apply specialized concern resolution:
  - prefer `Model::Concern` (for example `Article::Searchable`),
  - fallback to base concern (for example `::Searchable`).
- Apply method-level hooks where needed:
  - `before_discard(recording)`,
  - optional `event_action`,
  - permission methods (`editable_by?`, `deletable_by?`, `viewable_by?`),
  - broadcast hook methods for broadcastable types,
  - countable class hooks when countable.

6. Add or extend a recordable type.
- Add model/table.
- Include `Recordable`.
- Add type to `Recording::RECORDABLE_TYPES`.
- Add specialized concerns only for behaviors that differ from defaults.
- Integrate controller/view/filtering paths as needed.

7. Add tests using the project’s chosen test runner.
- Always use the target project’s runner.
- In this Rails project, use `rails test` (typically via Docker in this repo).
- Cover:
  - bucket ownership,
  - delegated type wiring,
  - tree traversal,
  - event creation on create/update/discard,
  - override behavior from specialized concerns and hooks.

8. Validate and summarize.
- Verify model callbacks and associations by running focused tests.
- Summarize what was added/changed and which concerns or overrides were introduced.

## Guardrails

- Keep recordables immutable; update by creating a new recordable row and repointing `Recording`.
- Keep cross-cutting behavior in concerns, not duplicated across recordables.
- Prefer specialized concern modules over ad hoc conditionals.
- Keep bucket scoping explicit in both schema and model behavior.
