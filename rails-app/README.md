# Marketplace

A Rails application demonstrating the Recording/Recordable delegated type pattern for content management with built-in event tracking and tree-based relationships.

## Getting Started

If you're running Docker it is as simple as cloning the repository and running a couple of make tasks:

```
make up
make server
```
Connect to the site as http://localhost:3000

If you're not running Docker then you'll have to figure things out for yourself.

## Architecture Overview

A bucket is the owner boundary for its content and access through memberships.
Each bucket may have at most one published menu at a time. Menu publication is a
domain requirement; menu functionality is not yet implemented in this application.
The admin sidebar must contain Products, Categories, Allergens, and Menus, in
that order. The main sidebar contains Overview and Orders, with an additional
Admin link for editors and admins. Admin includes a Back to Overview link.
Editors and admins can manage all four sections and publish menus.
Products, variants, and menus are archived, never deleted. All domain changes
must be tracked through events, including every product, variant, and allergen
change. Product, variant, and menu content uses immutable recordables; published
menus snapshot content, prices, and allergens while availability remains live.
Each bucket uses one currency.
The confirmed domain rules and remaining decisions are captured in
[Marketplace admin requirements](docs/context/marketplace-admin-requirements.md).
These requirements remain to be fully reflected in Figma and implemented in Rails.

This application uses a **delegated type pattern** where `Recording` serves as a polymorphic wrapper around immutable content types called **Recordables**. This design provides uniform behavior across all content types while maintaining clean separation of concerns.

## Delegated Type Pattern

The core of the architecture is the `Recording` model, which uses Rails' `delegated_type` to point to concrete content types:

```ruby
class Recording < ApplicationRecord
  delegated_type :recordable, types: %w[Article Comment PublicationState PersonCard]
end
```

**Recordables** (like `Article`, `Comment`) contain only their domain-specific attributes. Shared behavior lives on `Recording` through concerns:

- `Tree` - parent/child relationships
- `Eventable` - automatic change tracking
- `Publisher` - publication state management
- `Commenter` - comment access
- `Searcher` - full-text search

### Benefits

- **Single interface**: All content accessed uniformly through recordings
- **Shared concerns**: Cross-cutting functionality defined once on Recording
- **Easy extension**: New recordable types require no schema changes to recordings
- **Focused models**: Recordables contain only domain-specific logic

## Recording Tree Relationships

Instead of explicit `has_many`/`belongs_to` associations between models, relationships exist through the recording tree via `parent_id`:

### Traditional Approach

```ruby
class Article < ApplicationRecord
  has_many :comments
end

class Comment < ApplicationRecord
  belongs_to :article
end
```

### Recording Tree Approach

```ruby
# Article and Comment are both recordables
# Their relationship exists at the Recording level
article_recording.children.where(recordable_type: "Comment")

# Convenience method via Commenter concern
article_recording.comments
```

A Comment recording is simply a child of an Article recording. The `Tree` concern provides traversal methods:

```ruby
recording.parent      # Parent recording
recording.children    # Child recordings
recording.root        # Root of the tree
recording.ancestors   # All ancestors up to root
recording.descendants # All descendants
```

### Flexibility Trade-off

This trades explicit type-safe associations for:

- **Uniform traversal**: Same methods work for all parent/child relationships
- **Composable relationships**: Any recordable can potentially parent any other
- **Consistent patterns**: State (`PublicationState`) and content (`Comment`) use identical relationship patterns

The trade-off is that you lose direct association semantics where `article.comments` returns Comment objects. Instead, you query through recordings and filter by `recordable_type` at the recording level.

## Recordable Immutability

Recordables are **immutable** - they cannot be updated or destroyed:

```ruby
module Recordable
  included do
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }
  end
end
```

### How Updates Work

To "update" content, create a new recordable and update the Recording's `recordable_id`:

```ruby
# "Updating" an article
new_article = Article.create!(title: "Updated Title", body: "New content")
recording.update!(recordable: new_article)
```

### Benefits of Immutability

- **Safe sharing**: Multiple recordings can reference the same recordable
- **Complete history**: Previous versions remain in the database
- **No timestamps needed**: Recordable tables skip `created_at`/`updated_at` columns
- **Simplified concurrency**: No update conflicts on recordable data

## Automatic Event Tracking

The `Eventable` concern automatically tracks all changes to recordings without any explicit logging code:

```ruby
module Eventable
  included do
    after_create :track_created
    after_update :track_updated, if: :subject_changed?
  end
end
```

Every recording automatically gets:

- **Creation events**: Who created it and when
- **Update events**: Who changed the recordable, with before/after references
- **Person attribution**: All events link to `Current.person`

### What This Provides for Free

- **Full audit trail**: Complete history of all changes
- **Timeline views**: Events can be rendered as activity feeds
- **Creator access**: `recording.creator` returns the person who created it
- **Zero maintenance**: New recordable types automatically get event tracking

When you add a new recordable type, event tracking just works. No additional code, configuration, or callbacks required.

## State as Recordables

State changes are modeled as child recordings rather than fields on parent models:

```ruby
# Instead of article.published_at timestamp
# State exists as a child recording
article_recording.children.create!(recordable: PublicationState.published)

# Check state via Publisher concern
article_recording.published?
```

This means publishing an article creates an event, unpublishing creates another event, and the full state history is preserved in the recording tree.


## CSV imports and approvals

CSV uploads use `CsvImport`, persisted validation rows, and background processing.
Register CSV import types in an application initializer:

```ruby
Rails.application.config.x.csv_import_types = { "articles" => "Imports::Csv::Types::Articles" }
```

An adapter implements `.table_attributes`, `.from_row(raw_data)` (returning an
object with `valid?` and `errors`), and `.import(csv_import)`. A validator may
accept `bucket=` when it needs tenant context. The registry ships empty; the
sample adapter lives only in tests. Imports and approvals are restricted to
admins of the current bucket. Import actions and their supporting fragments
are available at `/admin/csv_imports`.

Models including `Approvable` may implement `on_approval(approval)`,
`approvable?`, `approval_lock`, and before/after approval callbacks. Additional
update adapters inherit from `ApprovalUpdates` and register their class names
in `Rails.application.config.x.approval_updates`, keyed by the approvable class
name. The CSV approval callback is provided; other subjects use `NullUpdates`.

Actions accept an optional `permissions:` object implementing
`allowed?(action, subject)`. `AllowAllActionsPolicy` is an explicit presenter
test/demo checker. Without injection, actions use the same policy dispatcher
as controllers. Missing policies and missing commands are denied.

Publishing now supports arbitrary models through the polymorphic `Publisher`
concern. Recording publication events and existing publication records are
preserved. `Discardable` also supports `restore!`, and application jobs carry
person/bucket context through their serialized payloads.

Storage defaults to the existing local service. For optional MinIO development
storage, set `ACTIVE_STORAGE_SERVICE=minio` in `.env` and start Docker with
`docker compose --profile storage up -d`. The storage profile provisions the
`blogger-development` bucket. Production can select `ACTIVE_STORAGE_SERVICE=bucketeer`
with the corresponding `BUCKETEER_*` environment variables from `config/storage.yml`.

Run `docker compose exec web bundle install` and
`docker compose exec web bin/rails db:migrate` after updating. Validate with
`docker compose exec web bin/rails test` and
`docker compose exec web bin/rubocop`.
