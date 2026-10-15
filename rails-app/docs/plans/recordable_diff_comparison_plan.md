# Recordable Diff Comparison Plan

## Goal

Add a general comparison screen for a `Recording` that shows the difference between the current recordable version and the previous version.

Version 1 compares:

- current version: `recording.recordable`
- previous version: the `subject_previous` on the latest `updated` event for that recording

The implementation should stay small and reuse Active Record Dirty for attribute comparison. It should not introduce a new versioning table, serialized diff payload, or recordable-specific comparison code.

## Core Decisions

1. Use existing event history as the version source.
   `Eventable` already records the current subject and previous subject when a recording changes recordable pointers. The comparison screen should read that history instead of duplicating it.

2. Compare only recordables of the same class.
   If the current and previous recordables are different classes, raise an exception. That indicates invalid history for this comparison screen, not an empty diff.

3. Use Active Record Dirty for changed attributes.
   Load the previous recordable as the clean baseline, assign current recordable attributes onto it, then read `changes`.

4. Let recordables define their comparable fields through `Diffable`.
   Add a small default field API through a `Diffable` concern, with model-level override support for recordables that need to hide or reorder fields later.

5. Keep the first UI simple.
   Render a field-level table with previous and current values. Do not add word-level or line-level text diffing in v1.

## Proposed Files

- `app/models/recordable_diff.rb`
- `app/models/concerns/differ.rb`
- `app/models/concerns/diffable.rb`
- `app/controllers/recordings/diffs_controller.rb`
- `app/views/recordings/diffs/show.html.erb`
- `test/models/recordable_diff_test.rb`
- `test/models/concerns/differ_test.rb`
- `test/models/concerns/diffable_test.rb`
- `test/controllers/recordings/diffs_controller_test.rb`

Route:

```ruby
resources :recordings, only: [] do
  resource :diff, only: :show, controller: "recordings/diffs"
end
```

## Recordable Field API

Add a default class method through `Diffable`:

```ruby
module Diffable
  extend ActiveSupport::Concern

  def diffable?
    true
  end

  class_methods do
    def recordable_fields
      attribute_names - %w[id created_at updated_at]
    end
  end
end
```

Include `Diffable` in the `Recordable::CONCERNS` stack so every recordable has a default diff contract and can specialize it with `Model::Diffable` later if needed.

Recordable classes can override this later:

```ruby
class Article < ApplicationRecord
  include Recordable

  def self.recordable_fields
    %w[title body]
  end
end
```

The diff object should use `current.class.recordable_fields`, filtered to attributes that exist on both records.

## Recording Differ API

Add a `Differ` concern to `Recording`:

```ruby
module Differ
  extend ActiveSupport::Concern

  def diffable?
    recordable.diffable?
  end

  def previous_diff
    RecordableDiff.previous(self)
  end
end
```

The controller and actions should call `recording.previous_diff` and `recording.diffable?` instead of constructing the diff object directly.

## Diff Object

Introduce a PORO:

```ruby
class RecordableDiff
  IncompatibleRecordableTypes = Class.new(StandardError)

  def self.previous(recording)
    event = recording.events
      .where(action: "updated")
      .where.not(subject_previous_type: nil, subject_previous_id: nil)
      .order(created_at: :desc)
      .first

    new(current: recording.recordable, previous: event&.subject_previous, event:)
  end

  attr_reader :current, :previous, :event

  def initialize(current:, previous:, event:)
    @current = current
    @previous = previous
    @event = event

    assert_comparable_recordables!
  end

  def changes
    return {} unless previous

    comparison = previous.class.find(previous.id)
    comparison.assign_attributes(current.attributes.slice(*fields))
    comparison.changes.slice(*fields)
  end

  def fields
    current.class.recordable_fields & previous.class.attribute_names
  end

  private

  def assert_comparable_recordables!
    return unless current && previous
    return if current.class == previous.class

    raise IncompatibleRecordableTypes,
      "Cannot compare #{current.class.name} with #{previous.class.name}"
  end
end
```

Notes:

- `previous.nil?` means there is no previous version to show.
- Different classes raise immediately.
- `previous.class.find(previous.id)` reloads a clean persisted object before assigning current attributes.
- `changes` returns Active Record's standard `{ "field" => [old_value, new_value] }` shape.

## Controller

Add a generic nested controller:

```ruby
class Recordings::DiffsController < ApplicationController
  before_action :set_recording

  def show
    head :forbidden unless @recording.viewable_by?(Current.person)

    @diff = @recording.previous_diff
  end

  private

  def set_recording
    @recording = recordings.find(params[:recording_id])
  end
end
```

Authorization should follow existing recording/recordable permission behavior. The controller should not rescue `RecordableDiff::IncompatibleRecordableTypes`; the exception should fail loudly.

## View

Render:

- heading identifying the current recordable
- empty state when no previous version exists
- empty state when a previous version exists but no comparable fields changed
- table of changed fields otherwise

Suggested table columns:

- Field
- Previous
- Current

Rendering rules:

- Use `to_s` for scalar values initially.
- Preserve whitespace for text values with CSS such as `white-space: pre-wrap`.
- Avoid type-specific partials in v1.

Add a link to the diff screen from the relevant recordable show page once the generic route exists. For the first pass, `articles/show` is enough because articles are the visible editable recordable today.

## Tests

### Model tests

Cover:

- returns no changes when there is no previous updated event
- finds the latest `updated` event with `subject_previous`
- reports changed fields using Active Record Dirty shape
- omits unchanged fields
- respects `recordable_fields`
- raises `RecordableDiff::IncompatibleRecordableTypes` when current and previous classes differ

### Controller tests

Cover:

- authorized users can view the diff screen
- unauthorized users are forbidden
- recordings are scoped through `recordings`
- no previous version renders an empty state
- changed fields render previous and current values

Run focused tests with Docker:

```bash
docker compose exec web rails test test/models/recordable_diff_test.rb
docker compose exec web rails test test/controllers/recordings/diffs_controller_test.rb
```

## Follow-Up Options

Later improvements can include:

- compare against a selected historical event
- side-by-side text diffing for long text attributes
- recordable-specific value formatting
- links from timeline update events into the comparison screen
- generalized comparison between any two versions of the same recordable class
