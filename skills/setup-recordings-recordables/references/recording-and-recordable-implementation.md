# Recording and Recordable Implementation Guide

This guide documents how `Recording` and `Recordable` are implemented in this app, including extension concerns (`Tree`, etc.) and override behavior.

## Overview

The app uses a delegated type pattern:
- `Recording` is the mutable wrapper and behavior hub.
- Recordables (for example, `Article` and `Comment`) are immutable content/state rows.
- Most cross-cutting behavior lives in concerns on `Recording` and `Recordable`.

Primary files:
- `app/models/bucket.rb`
- `app/models/recording.rb`
- `app/models/concerns/recordable.rb`
- `app/models/concerns/tree.rb`
- `app/models/article.rb`
- `app/models/comment.rb`

## 1. Database Structure

Core `recordings` table (`db/migrate/20260117165437_create_recordings.rb`):
- `bucket_id` (required FK)
- `parent_id` (self-reference FK, optional)
- `recordable_type` + `recordable_id` (required delegated type pointer)
- timestamps
- index on `[:recordable_type, :recordable_id]`

Soft delete support (`db/migrate/20260121080925_add_discarded_at_to_recordings.rb`):
- `discarded_at` datetime + index.

Concern-owned extension tables:
- `search_indices` (`db/migrate/20260119141253_create_search_indices.rb`)
- `counter_caches` (`db/migrate/20260120175719_create_counter_caches.rb`)
- `publications` (`db/migrate/20260123074443_create_publications.rb`)
- `events` / `event_details` for timeline and audit trail.

Bucket ownership model:
- `app/models/bucket.rb` owns many recordings.
- `Recording` belongs to a bucket (implemented via `Bucketable`).

## 2. Recording Model Assembly

`app/models/recording.rb` composes behavior with concerns:
- `Bucketable`
- `Discardable`
- `Counter`
- `Eventable`
- `Tree`
- `Timeline`
- `Commenter`
- `Publisher`
- `Broadcaster`
- `Searcher`
- `Permissible`

It declares:
- `RECORDABLE_TYPES` for allowed delegated recordable classes
- `delegated_type :recordable, types: RECORDABLE_TYPES, autosave: true`
- `belongs_to :bucket` through `Bucketable`

Important overrides in `Recording`:
- `model_name` delegates routing identity to the current `recordable` class.
- Eventable contract methods:
  - `current_subject`
  - `subject_changed?`
  - `previous_subject_type`
  - `previous_subject_id`

Validation:
- `validates_associated :recordable`
- Parent/child bucket consistency check (`bucket_matches_parent`).

## 3. Recording Concern Responsibilities

`Bucketable` (`app/models/concerns/bucketable.rb`)
- Ensures `bucket` is set on create.
- Priority: explicit bucket -> parent bucket -> `Current.bucket`.

`Tree` (`app/models/concerns/tree.rb`)
- Adds `parent`/`children` self-referential associations.
- Traversal helpers: `root`, `ancestors`, `descendants`.
- Child updates touch parent (`touch: true` on `belongs_to :parent`).

`Discardable` (`app/models/concerns/discardable.rb`)
- Soft deletion with `discarded_at`.
- Scopes: `kept`, `discarded`.
- Hook support: `before_discard`, `after_discard`.
- On discard: optional recordable callback -> discarded event -> set `discarded_at`.

`Eventable` (`app/models/concerns/eventable.rb`)
- Tracks create/update events.
- Expects the four subject methods implemented by including model.
- Uses `Current.person` when available.
- Supports optional `event_action` override on `current_subject`.

`Timeline` (`app/models/concerns/timeline.rb`)
- Fetches timeline events from self + descendants.
- Resolves historical subject/ancestor subject at event time.

`Commenter` (`app/models/concerns/commenter.rb`)
- Returns direct comment children when the current recordable is commentable.

`Counter` (`app/models/concerns/counter.rb`)
- Maintains counter caches on parent recordings for countable recordables.
- Increments on create, decrements on discard, supports manual refresh.

`Publisher` (`app/models/concerns/publisher.rb`)
- `publish!` / `unpublish!` for publishable recordables.
- Persists `Publication` row and creates published/unpublished events.

`Broadcaster` (`app/models/concerns/broadcaster.rb`)
- Delegates create/update/discard broadcasts to recordable hooks when broadcastable.

`Searcher` (`app/models/concerns/searcher.rb`)
- Manages `search_index` row from recordable content.
- Adds class method `Recording.search(query, recordable_type: nil)`.
- Removes search index on discard.

`Permissible` (`app/models/concerns/permissible.rb`)
- Delegates `editable_by?`, `deletable_by?`, `viewable_by?` to recordable.

## 4. Recordable Concern Stack and Override Behavior

`Recordable` (`app/models/concerns/recordable.rb`) does two things:
- Adds `has_one :recording, as: :recordable, touch: true`.
- Includes a standard concern list:
  - `Broadcastable`, `Commentable`, `Countable`, `Describable`, `Immutable`, `Publishable`, `Searchable`.

### Specialized Concern Resolution (Primary Override Mechanism)

For each concern, `Recordable` checks:
- `#{ModelName}::#{ConcernName}` first (specialized concern),
- falls back to global `::ConcernName`.

Example:
- `Article::Searchable` overrides default `Searchable`.
- `Comment::Broadcastable` overrides default `Broadcastable`.

This is implemented by:
- `specialized = "#{name}::#{concern_name}".safe_constantize`
- `include specialized || concern_name.to_s.constantize`

### Default Behavior vs Override Contract

Default concerns are conservative:
- `broadcastable?` -> `false`
- `commentable?` -> `false`
- `publishable?` -> `false`
- `searchable?` -> `false`
- `timeline_description` -> generic model name
- `Countable.countable?` -> `false`
- `Countable.count_for` -> raises `NotImplementedError`
- `Searchable#searchable_content` -> raises `NotImplementedError`

To enable a capability, override in either:
- specialized concern module (`app/models/<model>/<concern>.rb`), or
- model class directly (used in this codebase for some methods).

## 5. Method-Level Override Hooks

These hooks are consumed by concerns and should be documented when adding new recordables:

- `before_discard(recording)` (optional):
  Called by `Discardable` before soft delete. Used by `Article`/`Comment` to cascade discard to children.

- `event_action` (optional):
  If present on `current_subject`, `Eventable` uses it for create/update action names instead of defaults.

- Permission methods (required for practical use):
  - `editable_by?(person)`
  - `deletable_by?(person)`
  - `viewable_by?(person)`
  `Permissible` delegates to these.

- Broadcast hooks (only if `broadcastable?` true):
  - `broadcast_on_create(recording)`
  - `broadcast_on_update(recording)`
  - `broadcast_on_discard(recording)`

- Countable class hooks (only if countable):
  - `.countable?` -> true
  - `.count_for(recording)` implementation
  - optional `.counter_name` override

## 6. Existing Recordable Implementations

`Article` (`app/models/article.rb`)
- Includes `Recordable`.
- Enables `commentable?` and `publishable?`.
- Implements `before_discard` cascade.
- Implements permission methods.
- Specialized concerns:
  - `app/models/article/describable.rb`
  - `app/models/article/searchable.rb`

`Comment` (`app/models/comment.rb`)
- Includes `Recordable`.
- Implements `before_discard` cascade.
- Implements permission methods.
- Specialized concerns:
  - `app/models/comment/broadcastable.rb`
  - `app/models/comment/countable.rb`
  - `app/models/comment/describable.rb`
  - `app/models/comment/searchable.rb`

## 7. Add a New Recordable Type

1. Create model + table (typically immutable table without update usage).
2. Include `Recordable` in the model.
3. Add the class name to `Recording::RECORDABLE_TYPES`.
4. Add any specialized concerns under `app/models/<model_name>/` as needed.
5. Implement permission methods on the recordable.
6. Add optional hooks (`before_discard`, broadcast hooks, etc.) if required.
7. Add UI/controller integration and whitelist type filters where relevant.
8. Add/extend tests for enabled concerns.

Write tests using the test runner chosen by the target project.
In this project, that runner is `rails test` (Minitest).

Commands (Docker):

```bash
docker compose exec web rails g model YourType ...
docker compose exec web rails db:migrate
docker compose exec web rails test test/models/concerns/tree_test.rb
docker compose exec web rails test test/models/concerns/commenter_test.rb
docker compose exec web rails test test/models/concerns/counter_test.rb
docker compose exec web rails test test/models/concerns/searcher_test.rb
```

## 8. Runtime Lifecycle Summary

On create:
- Bucket assigned (`Bucketable`) -> event created (`Eventable`) -> counters/search index/broadcast callbacks run via other concerns.

On update (recordable pointer change):
- Recording points to a new immutable recordable -> update event created -> search index refreshed -> update broadcast hook (if enabled).

On discard:
- `before_discard` callbacks and optional recordable cascade.
- discarded event tracked.
- `discarded_at` set.
- after_discard callbacks run (counter decrement, search index destroy, broadcast discard).
