# Event Model Implementation Guide

This guide describes how the event system is implemented in this app and how to wire new eventable behavior safely.

## Overview

`Event` is an immutable audit/timeline record. It tracks:
- Which record emitted the event (`eventable`, polymorphic).
- What object the event is about (`subject`, polymorphic).
- Optional previous subject (`subject_previous`) for change history.
- Who triggered the event (`person`, optional).
- What happened (`action`).
- Optional key/value metadata (`Event::Detail` rows).

Core files:
- `app/models/bucket.rb`
- `app/models/event.rb`
- `app/models/event/detail.rb`
- `app/models/concerns/eventable.rb`
- `app/models/recording.rb`
- `app/models/concerns/discardable.rb`
- `app/models/concerns/timeline.rb`
- `app/helpers/timelines_helper.rb`
- `app/views/timelines/_timeline.html.erb`
- `app/views/timelines/_event.html.erb`
- `app/views/timelines/events/_wrapper.html.erb`
- `db/migrate/20260117165453_create_events.rb`
- `db/migrate/20260117165458_create_event_details.rb`

## 1. Create the Database Tables

Use migrations with Docker:

```bash
docker compose exec web rails g migration CreateEvents
docker compose exec web rails g migration CreateEventDetails
```

`events` table should include:
- `bucket` reference (required, FK).
- `eventable_type` and `eventable_id` (required).
- `subject_type` and `subject_id` (required).
- `subject_previous_type` and `subject_previous_id` (optional).
- `action` (required).
- `person_id` (optional, FK to `people`).
- `created_at` only (no `updated_at`, by design).

Indexes to include:
- `[:eventable_type, :eventable_id]`
- `[:subject_type, :subject_id]`
- `[:subject_previous_type, :subject_previous_id]` (named index is fine).

`event_details` table should include:
- `event` reference (required, FK).
- `key` (required).
- `value` (text, optional).
- Unique index on `[:event_id, :key]`.

Run migrations:

```bash
docker compose exec web rails db:migrate
```

## 2. Implement `Event`

`Event` lives in `app/models/event.rb` and should:
- Include `Bucketable` so bucket is always present.
- Include `Immutable` so updates/deletes raise `ActiveRecord::ReadOnlyRecord`.
- Define polymorphic relations:
  - `belongs_to :eventable, polymorphic: true, touch: true`
  - `belongs_to :subject, polymorphic: true`
  - `belongs_to :subject_previous, polymorphic: true, optional: true`
- Associate actor: `belongs_to :person, optional: true`.
- Own details: `has_many :details, class_name: "Event::Detail", dependent: :destroy`.
- Validate `action`.
- Broadcast timeline append in `after_create_commit`.

The model resolves a specialized partial path:
- Preferred: `timelines/events/_#{action}_#{subject_type.underscore}.html.erb`
- Fallback: `timelines/event`

## 3. Implement `Event::Detail`

`app/models/event/detail.rb`:
- `self.table_name = "event_details"`.
- `belongs_to :event`.
- Include `Immutable`.
- Validate `key` presence and uniqueness scoped to `event_id`.

Use details when a simple structured payload is needed without changing the `events` table.

## 4. Implement the `Eventable` Concern Contract

`app/models/concerns/eventable.rb` provides default event tracking:
- `after_create :track_created`
- `after_update :track_updated, if: :subject_changed?`
- `has_many :events, as: :eventable, dependent: :restrict_with_exception`

It requires the including class to implement:
- `current_subject`
- `subject_changed?`
- `previous_subject_type`
- `previous_subject_id`

It also supports action overrides if `current_subject` responds to `event_action`:
- Create action defaults to `"created"`.
- Update action defaults to `"updated"`.

It assigns actor from `Current.person` when available.

## 5. Wire `Eventable` Into the Owning Model

In this app, `Recording` is the event emitter (`app/models/recording.rb`):
- Belongs to `Bucket` (via `Bucketable` / `belongs_to :bucket`), and each generated event is bucket-scoped.
- Includes `Eventable`.
- Implements the required methods:

```ruby
def current_subject = recordable
def subject_changed? = saved_change_to_recordable_type? || saved_change_to_recordable_id?
def previous_subject_type = recordable_type_before_last_save
def previous_subject_id = recordable_id_before_last_save
```

If you include `Eventable` in a different model, implement equivalent methods for that model’s subject columns.

## 6. Include Other Event Producers

Some events are produced outside create/update callbacks:
- `Discardable#discard!` calls `track_discarded` (`app/models/concerns/discardable.rb`).
- `Publisher` creates `"published"`/`"unpublished"` events (`app/models/concerns/publisher.rb`).

If you add custom actions, keep action names consistent with timeline partial naming.

## 7. Timeline Query and Rendering

Timeline aggregation and historical resolution:
- `app/models/concerns/timeline.rb` defines:
  - `timeline_events`
  - `subject_at(event)`
  - `ancestor_at(type, event)`

Rendering path selection:
- `app/helpers/timelines_helper.rb#event_partial_path`

Views:
- `app/views/timelines/_timeline.html.erb` loops events.
- `app/views/timelines/_event.html.erb` is generic fallback.
- Add specialized partials at:
  - `app/views/timelines/events/_<action>_<subject_type.underscore>.html.erb`
  - Example: `_created_comment.html.erb`

## 8. Testing Checklist

Write tests using the test runner chosen by the target project.
In this project, that runner is `rails test` (Minitest).

Existing tests to mirror/extend:
- `test/models/concerns/eventable_test.rb`
- `test/models/concerns/discardable_test.rb`
- `test/models/concerns/publisher_test.rb`
- `test/models/concerns/timeline_test.rb`
- `test/models/concerns/describable_test.rb`

Run relevant tests with Docker:

```bash
docker compose exec web rails test test/models/concerns/eventable_test.rb
docker compose exec web rails test test/models/concerns/timeline_test.rb
```

## 9. Common Pitfalls

- Missing `Current.bucket` or `bucket` assignment causes `Bucketable` failures.
- Missing required `Eventable` methods raises `NotImplementedError`.
- Missing specialized timeline partials is okay, fallback partial is used.
- Deleting records with events can raise due to `restrict_with_exception`; this is expected for audit integrity.
