# CSV Import Plan

## Goal

Provide a generic CSV import workflow with:

- Upload-level approval.
- Row-level validation.
- Generic table rendering driven by the selected import type.
- Raw CSV retention through Active Storage, backed by S3 outside local/test environments.
- Persisted row data and validation errors for review before approval processing.

The implementation should model this as an operational workflow, not as recordable content.

`CsvImport` is an ingress holding area. Its job is to retain the raw CSV, extract rows, map fields, validate data, flag duplicates, and present the file for a whole-file decision. Domain objects are only created when the import is approved.

## Proposed Model Names

Use:

- `CsvImport`
- `CsvImportRow`

Rationale:

- The source format is explicitly CSV.
- The target behavior remains generic through import type classes.
- `Upload` is too narrow because the parent model owns mapping, validation, approval, rejection, and row processing behavior.
- `Row` is too generic without the parent prefix.

If the feature later supports non-CSV sources, rename or generalize to:

- `Import`
- `ImportRow`

with a `source_format` column.

## Data Model

### `csv_imports`

Suggested columns:

- `bucket_id`, required, foreign key to `buckets`.
- `created_by_id`, optional or required, foreign key to `people`.
- `import_type`, string, required, constrained to known import type keys.
- `header_mapping`, jsonb, required, default `{}`.
- `source_headers`, jsonb, required, default `[]`.
- timestamps.

Indexes:

- `bucket_id`
- `created_by_id`
- `import_type`

Model validations:

- Validate `import_type` presence.
- Validate `import_type` inclusion in `Imports::Csv::Types.keys`.
- Validate attached source file presence.
- Validate attached source file content type and size.

Associations:

```ruby
has_one_attached :source_file
```

Do not add `original_filename` unless the product needs a display alias independent of the uploaded blob. Active Storage already stores filename, content type, byte size, and checksum on the blob.

Do not add workflow status columns at this stage. The import's state should be derived from the data it owns:

- Parsed: rows exist.
- Mapped: required target attributes have header mappings.
- Validated: every row has a non-null validation result.
- Approvable: every row has an empty validation result and satisfies the duplicate policy.
- Approved: a `CsvImport::Approval` exists for the import.
- Rejected: a `CsvImport::Rejection` exists for the import.
- Processed: approved rows have created target records or other import-type-specific side effects.

### `csv_import_rows`

Suggested columns:

- `csv_import_id`, required, foreign key.
- `row_number`, integer, required.
- `raw_data`, jsonb, required, default `{}`.
- `mapped_data`, jsonb, required, default `{}`.
- `row_hash`, string, nullable.
- `duplicate`, boolean, default `false`, null false.
- `validation_errors`, jsonb, nullable.
- `imported_recording_id`, optional, foreign key to `recordings` if the import creates recordables.
- timestamps.

Indexes:

- `csv_import_id`
- `[csv_import_id, row_number]`, unique.
- `[csv_import_id, row_hash]`
- `[csv_import_id, duplicate]`
- `row_hash`
- `imported_recording_id`

`validation_errors` should be nullable:

- `NULL`: row has not been validated against the current mapping.
- `{}`: row has been validated and is valid.
- `{ "field": ["message"] }`: row has been validated and is invalid.

Do not add an `invalid` boolean initially. Invalidity is already represented by non-empty `validation_errors`, while `NULL` preserves the important distinction between unvalidated and valid. If filtering invalid rows becomes a measured bottleneck, add a derived/cache boolean later and update it in the same transaction as `validation_errors`.

Do not move validation errors into a separate model initially. A separate `CsvImportRowValidationError` table makes individual errors easier to query, but it loses the clean three-state behavior unless another marker is added:

- no error rows because validation has not run
- no error rows because validation passed
- one or more error rows because validation failed

The nullable JSONB column represents that directly without a row status column, validation timestamp, or validation-run model. Promote errors to a separate model only if the UI needs to filter/group by individual error type at scale, assign/acknowledge errors independently, or retain validation history.

If promoted later, use a shape like:

- `csv_import_row_id`, required, foreign key.
- `attribute`, string, nullable for base errors.
- `code`, string, optional stable machine key.
- `message`, text, required.
- `details`, jsonb, required, default `{}`.

That change should also introduce either `csv_import_rows.validated_at` or a first-class validation run model so valid rows remain distinguishable from unvalidated rows.

If approval processing needs a generic result link rather than `imported_recording_id`, use a polymorphic pair such as:

- `imported_record_type`
- `imported_record_id`

Only add that once a non-recording import type needs it.

`row_hash` is a derived fingerprint used for duplicate detection. It should not be unique at the database level, because duplicate CSV rows need to be persisted so the review UI can show and explain them.

`duplicate` is acceptable as a persisted derived flag because it supports filtering/review without forcing duplicate detection into validation errors or row creation constraints.

### `csv_import_approvals` and `csv_import_rejections`

Approval and rejection are decisions about a `CsvImport` record.

The import type is not an Active Record model and should not be represented as `approvable_type` / `approvable_id`. The selected type is already stored on `csv_imports.import_type`; approval processing resolves that key through `Imports::Csv::Types`.

Use models such as `CsvImport::Approval` and `CsvImport::Rejection`, backed by `csv_import_approvals` and `csv_import_rejections`.

Suggested `csv_import_approvals` columns:

- `csv_import_id`, required, foreign key.
- `person_id`, required, foreign key to `people`.
- timestamps.

Indexes:

- `csv_import_id`, unique.
- `person_id`

The approval timestamp is `csv_import_approvals.created_at`. There is no need for `csv_imports.approved_at` or `csv_imports.approved_by_id`.

Suggested `csv_import_rejections` columns:

- `csv_import_id`, required, foreign key.
- `person_id`, required, foreign key to `people`.
- `reason`, text, optional.
- timestamps.

Indexes:

- `csv_import_id`, unique.
- `person_id`

The rejection timestamp is `csv_import_rejections.created_at`. There is no need for `csv_imports.rejected_at` or `csv_imports.rejected_by_id`.

Approval and rejection should be mutually exclusive for the same CSV import. Enforce that in model/service logic first; add database constraints later only if this pattern becomes shared enough to justify the extra structure.

## File Storage

Store the uploaded CSV as the raw source of truth with Active Storage.

Development and test can continue using disk-backed Active Storage. Production should use S3:

```ruby
gem "aws-sdk-s3", require: false
```

```yaml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: <%= Rails.application.credentials.dig(:aws, :region) %>
  bucket: <%= Rails.application.credentials.dig(:aws, :bucket) %>
```

Production should then use:

```ruby
config.active_storage.service = :amazon
```

The raw download link should be generated from `csv_import.source_file`, not from reconstructed row data. Rows are extracted for review, validation, and approval processing; the attached file remains the auditable original.

If Active Storage tables are not already installed in the app schema, add the Active Storage migrations as part of the first implementation step.

## Import Type Contract

Each import type should be represented by a code-level class. The class carries:

- ActiveModel attributes, which define target fields and scalar types.
- ActiveModel validations for row validation.
- Presentation hooks for generic table ordering, labels, and optional help text.
- Approval behavior for processing a validated row when the whole file is approved.

The type is selected by `csv_imports.import_type`. It is not persisted as its own model; it is a registry-backed ActiveModel class.

Example namespace:

```ruby
Imports::Csv::Types::Article
Imports::Csv::Types::PersonCard
```

Example contract:

```ruby
module Imports
  module Csv
    module Types
      class Article
        include ActiveModel::Model
        include ActiveModel::Attributes

        def self.key = "article"

        def self.table_attributes
          %i[title body]
        end

        def self.fingerprint_attributes
          table_attributes
        end

        def self.field_help
          {}
        end

        attribute :title, :string
        attribute :body, :string

        validates :title, presence: true

        def approve!(row:, approved_by:)
          # Create records or call domain methods for this approved row.
        end
      end
    end
  end
end
```

`approve!` is intentionally type-specific. It may create records, call domain methods, create events, or attach the approved row to a created object. The generic CSV import code should only orchestrate when that method is called; it should not know the domain behavior for each import type.

The generic UI can inspect the type class instead of reading a parallel schema:

```ruby
type = Imports::Csv::Types.fetch(csv_import.import_type)

type.table_attributes.each do |attribute_name|
  attribute_type = type.attribute_types.fetch(attribute_name.to_s)
  required = type.validators_on(attribute_name).any? do |validator|
    validator.kind == :presence
  end
  label = type.human_attribute_name(attribute_name)
  help = type.field_help[attribute_name]
end
```

Avoid storing arbitrary class names from user input. Use a registry:

```ruby
module Imports
  module Csv
    module Types
      REGISTRY = {
        "article" => Article
      }.freeze

      def self.fetch(key)
        REGISTRY.fetch(key)
      end

      def self.keys
        REGISTRY.keys
      end
    end
  end
end
```

## Field Metadata

Do not maintain a separate column definition structure with duplicated type information.

The selected import type is the source of truth:

- Field keys come from `table_attributes`.
- Scalar types come from `attribute_types`.
- Required markers come from validators, usually presence validators.
- Labels come from `human_attribute_name`.
- Optional help text comes from a small presentation hook such as `field_help`.

If future compatibility requires preserving historical behavior across code changes, add explicit import type versioning. Do not start by snapshotting a second schema unless there is a concrete need.

## Header Mapping

Store mappings on the parent import:

```json
{
  "title": "Post Title",
  "body": "Content"
}
```

Meaning:

- Key: canonical target attribute.
- Value: source CSV header.

Keep `source_headers` separately so the UI can render unmapped source headers.

When mapping changes:

- Rebuild `mapped_data` for each row.
- Rebuild `row_hash` for each row.
- Rebuild `duplicate` for each row.
- Clear row `validation_errors` back to `NULL`.
- Destroy any existing approval, because the approved data has changed.

Mapping changes should enqueue `CsvImportValidateRowsJob`, rather than performing validation in the request cycle.

## Background Processing

CSV parsing, row extraction, row hashing, duplicate detection, and validation should run through Active Job on Solid Queue.

Suggested jobs:

- `CsvImportExtractRowsJob`
- `CsvImportValidateRowsJob`

Upload request flow:

1. Create `CsvImport`.
2. Attach `source_file`.
3. Enqueue `CsvImportExtractRowsJob.perform_later(csv_import)`.
4. Return the user to the import page while rows are extracted in the background.

`CsvImportExtractRowsJob` responsibilities:

- Lock the import before mutating rows.
- Read the original file from `csv_import.source_file`.
- Parse CSV headers into `source_headers`.
- Create `CsvImportRow` records with `row_number` and `raw_data`.
- Avoid validation unless `header_mapping` is already present and complete.
- If mapping is present, enqueue `CsvImportValidateRowsJob`.

`CsvImportValidateRowsJob` responsibilities:

- Lock the import before mutating rows.
- Apply `header_mapping` into each row's `mapped_data`.
- Compute `row_hash`.
- Compute bucket-scoped `duplicate` flags.
- Instantiate the import type for each row and persist normalized `validation_errors`.
- Destroy any existing approval before mutating row data.

Both jobs should be idempotent. Re-running extraction should either replace the unapproved/unprocessed rows or upsert by `[csv_import_id, row_number]`; re-running validation should overwrite `mapped_data`, `row_hash`, `duplicate`, and `validation_errors`.

Do not add import-level processing state columns initially. The UI can derive:

- Upload received: attached `source_file` exists.
- Extraction pending/running: attached file exists and no rows exist.
- Extraction complete: rows exist.
- Validation complete: all rows have non-null `validation_errors`.

If product UX later needs explicit job failure display or retry history, add a separate import processing attempt model rather than adding ad hoc state columns to `csv_imports`.

## Turbo Stream Feedback

Background jobs should push import progress back to the open import page with Turbo Streams.

The import show page should subscribe to a stream for the import:

```erb
<%= turbo_stream_from @csv_import %>
```

Use stable targets for the parts of the page that change as jobs run:

- `dom_id(csv_import, :summary)`: file, row, validation, duplicate, approval/rejection, and processing summary.
- `dom_id(csv_import, :mapping)`: mapping form/state after headers are extracted.
- `dom_id(csv_import, :rows)`: row table or paginated row frame.
- `dom_id(csv_import, :actions)`: approve/reject buttons.

`CsvImportExtractRowsJob` should broadcast after extraction:

- Replace the summary.
- Replace the mapping area once `source_headers` are known.
- Replace the row table or row count.

`CsvImportValidateRowsJob` should broadcast after validation:

- Replace the summary.
- Replace the row table or visible row slice.
- Replace the action area so approval availability updates.

Use the local broadcasting style already present in the app:

```ruby
Turbo::StreamsChannel.broadcast_replace_to(
  csv_import,
  target: ActionView::RecordIdentifier.dom_id(csv_import, :summary),
  partial: "csv_imports/summary",
  locals: { csv_import: csv_import }
)
```

Avoid broadcasting once per row for large files. Jobs should update rows in bulk and then broadcast coarse page regions. If the row table is paginated or filtered, broadcast the summary and currently visible frame rather than trying to stream every row mutation.

## Row Data

Persist both source and mapped data.

`raw_data` example:

```json
{
  "Post Title": "Hello",
  "Content": "Body text"
}
```

`mapped_data` example:

```json
{
  "title": "Hello",
  "body": "Body text"
}
```

Rationale:

- `raw_data` supports audit and remapping.
- `mapped_data` supports review and validation.
- The approval screen can show exactly what will be imported.

## Row Hashing

Each row should get a deterministic hash after mapping is applied.

The hash input should include:

- The import type key.
- The canonical mapped values for the import type's fingerprint attributes.

Do not hash `raw_data`; duplicate detection should not depend on CSV header names, source column order, or unmapped source columns.

Suggested implementation:

```ruby
type = Imports::Csv::Types.fetch(csv_import.import_type)
candidate = type.new(row.mapped_data)

payload = {
  import_type: csv_import.import_type,
  values: type.fingerprint_attributes.index_with do |attribute_name|
    candidate.public_send(attribute_name)
  end
}

row_hash = Digest::SHA256.hexdigest(JSON.generate(payload))
```

Using the candidate object means hashes are based on ActiveModel-cast values, so equivalent inputs such as `"1"` and `1` hash consistently for integer attributes. `fingerprint_attributes` can default to `table_attributes`, but each import type can override it if display fields and duplicate identity differ.

Duplicate detection should update `duplicate`, not prevent row creation.

The scope is the bucket, through the parent import:

- Duplicates within the current CSV import.
- Duplicates against previously approved/processed imports in the same bucket.
- No duplicate relationship across different buckets.

For duplicates within the current import:

```ruby
duplicate_hashes = csv_import.csv_import_rows
  .where.not(row_hash: nil)
  .group(:row_hash)
  .having("COUNT(*) > 1")
  .pluck(:row_hash)

csv_import.csv_import_rows.update_all(duplicate: false)
csv_import.csv_import_rows.where(row_hash: duplicate_hashes).update_all(duplicate: true)
```

For duplicates against existing approved/processed rows in the same bucket:

```ruby
existing_duplicate_hashes = CsvImportRow
  .joins(:csv_import)
  .where(csv_imports: { bucket_id: csv_import.bucket_id })
  .where.not(csv_import_id: csv_import.id)
  .where.not(imported_recording_id: nil)
  .where(row_hash: csv_import.csv_import_rows.where.not(row_hash: nil).select(:row_hash))
  .distinct
  .pluck(:row_hash)

csv_import.csv_import_rows.where(row_hash: existing_duplicate_hashes).update_all(duplicate: true)
```

Because the hash payload includes `import_type`, the same values can be considered distinct for different import types.

Whether `duplicate = true` blocks approval is a policy decision. It should not block `CsvImportRow` creation.

## Validation Flow

Validation should instantiate the import type for each row:

```ruby
type = Imports::Csv::Types.fetch(csv_import.import_type)

csv_import.csv_import_rows.find_each do |row|
  candidate = type.new(row.mapped_data)

  row.update!(
    validation_errors: candidate.valid? ? {} : candidate.errors.to_hash
  )
end
```

Persist errors as normalized JSON only:

```json
{
  "title": ["can't be blank"]
}
```

Do not persist `ActiveModel::Errors` directly.

After the row pass:

- Valid rows are rows with `validation_errors = {}`.
- Invalid rows are rows with non-empty `validation_errors`.
- Unvalidated rows are rows with `validation_errors IS NULL`.

If any row is invalid, the import can still be reviewable, but it should not be approvable.

## Batch Validation

Support row-level and batch-level validation separately.

Row-level examples:

- Required title.
- Valid email format.
- Valid date.
- Enum inclusion.

Batch-level examples:

- Duplicate values inside the CSV.
- Duplicate row hashes inside the CSV, persisted via `duplicate`.
- Duplicate row hashes from previously approved/processed imports in the same bucket, persisted via `duplicate`.
- Values that already exist in the database.
- Parent/child references between rows.

Batch validation can attach errors to individual rows by updating `validation_errors`, update derived flags like `duplicate`, or attach import-level errors to the parent if the problem is not row-specific.

## Approval Flow

Suggested approval rules:

- Import must be validated.
- All rows must be valid.
- Approval is a whole-file decision.
- Approval creates a `CsvImport::Approval` row for the import and removes any existing rejection.
- The approver is `approval.person`.
- The approval time is `approval.created_at`.
- Any mapping or row data change after approval should be refused once rows have been processed. If an approved import has not been processed yet, changing row data must destroy the approval.
- Approval revalidates before creating records or calling domain methods.
- Approval processes each eligible row through the selected import type's `approve!` method.

Suggested rejection rules:

- Rejection is a whole-file decision.
- Rejection creates a `CsvImport::Rejection` row for the import and removes any existing approval.
- Rejection does not process rows.
- Rejected imports remain available for raw CSV download and review.
- Mapping or row data changes after rejection should destroy the rejection.

Suggested methods:

```ruby
csv_import.ready_for_approval?
csv_import.approve!(person)
csv_import.reject!(person, reason: nil)
csv_import.revoke_approval!
csv_import.revoke_rejection!
```

## Approval Processing

Approval processing should be a separate service object or job:

```ruby
Imports::Csv::Approve.call(csv_import, approved_by: person)
```

Responsibilities:

- Lock the import row during approval processing to prevent duplicate processing.
- Revalidate current mapped data.
- Refuse approval unless every row is valid and the duplicate policy passes.
- Create the `CsvImport::Approval` row.
- Clear any `CsvImport::Rejection` row.
- For each eligible row, instantiate the import type with `mapped_data`.
- Call `candidate.approve!(row: row, approved_by: person)`.
- Persist created record references on rows where useful.
- Derive processing completion from row result links.

When row processing only writes to the local database, wrap approval creation and row processing in one transaction. If a type later performs non-transactional external side effects, add idempotency and a processing attempt model before allowing that behavior.

If imports create recordables, rows can store `imported_recording_id`. In that case, a row has been processed when `imported_recording_id` is present.

Do not add `imported_at` or `processed_at` to `csv_imports` initially. `csv_imports.created_at` is the upload/import record creation time, the approval time is `approvals.created_at`, and created target records already have their own `created_at` timestamps. If the product later needs an explicit processing attempt audit trail, add a processing attempt model rather than a timestamp column on `csv_imports`.

## Future Row Ignoring

Future versions should support tagging rows to be ignored before approval.

This should be row-level review metadata, not validation state. A likely shape is:

- `ignored`, boolean, default `false`, null false.
- `ignored_by_id`, optional foreign key to `people`, if audit is needed.
- `ignored_at`, optional datetime, if audit is needed.

Approval would then process eligible rows only:

```ruby
csv_import.csv_import_rows.where(ignored: false)
```

Ignored rows should remain visible in the review UI and raw audit trail. They should not be deleted just because they are excluded from approval processing. The duplicate and validation policy can then decide whether ignored rows are allowed to remain invalid or duplicate without blocking whole-file approval.

## Controller Shape

The upload controller should be generic, following the same broad pattern as `CommentsController`.

Use one controller for all CSV import uploads:

```ruby
class CsvImportsController < ApplicationController
  def create
    @csv_import = CsvImport.new(csv_import_params)
    @csv_import.created_by = Current.person

    if @csv_import.save
      CsvImportExtractRowsJob.perform_later(@csv_import)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @csv_import, notice: "CSV import was uploaded." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "csv_import_form",
            partial: "csv_imports/form",
            locals: { csv_import: @csv_import }
          )
        end
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end
end
```

The controller should not know about individual import types beyond accepting `import_type` as a validated parameter. Type-specific behavior belongs in:

- `Imports::Csv::Types`
- row extraction/mapping/validation services
- Solid Queue jobs
- approval processing services

On successful Turbo submission, mirror the comments flow:

- Replace `csv_import_form` with a fresh form.
- Let the background job update the import show page via Turbo Streams.

If uploads happen from an imports index, the success response can also prepend or replace a generic import summary row, but that should still use generic `csv_imports/*` partials. The first pass can keep this simple: reset the form and give the created import a normal link/show page.

Suggested successful response:

```erb
<%= turbo_stream.replace "csv_import_form" do %>
  <%= render "csv_imports/form", csv_import: CsvImport.new %>
<% end %>
```

## Services

Suggested service objects:

- `Imports::Csv::Parse`
- `Imports::Csv::ApplyMapping`
- `Imports::Csv::Validate`
- `Imports::Csv::Approve`
- `Imports::Csv::Reject`

Suggested jobs:

- `CsvImportExtractRowsJob`
- `CsvImportValidateRowsJob`

Keep models focused on associations, validations, derived predicates, and small transition methods.

## UI Shape

Generic screens can be driven by the import type class, `source_headers`, `header_mapping`, row validation results, duplicate flags, approvals, and row result links.

Suggested screens:

- New import: choose import type and upload CSV.
- Generic upload create: submit to `CsvImportsController#create`; on success replace the form with a fresh form.
- Import processing: show extraction/validation progress derived from attached file, rows, and validation results.
- Live updates: subscribe with `turbo_stream_from @csv_import` and replace summary, mapping, rows, and actions as jobs complete.
- Raw file download: link to the attached `source_file`.
- Mapping: map source headers to target attributes.
- Validation/review: show row table and validation errors.
- Approval: confirm valid, invalid, and duplicate row counts derived from row data.
- Rejection: capture an optional reason and leave the import available for review/download.
- Approval result: show processed row count derived from result links.

Table fields come from the selected import type, not hardcoded views.

## Open Decisions

- Whether invalid rows can be ignored and the rest approved.
- Whether duplicate rows block approval or only show a warning.
- Whether approval requires a different person than the creator.
- Whether a CSV import needs one approval or multiple approvals.
- Whether each import type creates `Recording` recordables, plain operational records, or a mix.
- Whether import type definitions need explicit versioning for historical imports.
- Whether ignored rows need audit columns immediately or only an `ignored` boolean.
- Whether validation errors eventually need a first-class table for filtering/history.
- Whether job failure/retry history needs a first-class processing attempt model.

## Initial Implementation Order

1. Add Active Storage setup if missing, then add `CsvImport` and `CsvImportRow` models and migrations.
2. Add import type registry and one concrete type.
3. Configure S3-backed Active Storage for production.
4. Add upload/create flow with `source_file` attachment and raw download.
5. Add generic `CsvImportsController#create` Turbo flow that replaces the upload form.
6. Add `CsvImportExtractRowsJob` to parse the attached file into rows.
7. Add `CsvImportValidateRowsJob` for mapping, row hashing, duplicate detection, and validation.
8. Add Turbo Stream feedback from extraction/validation jobs.
9. Add generic review table using import type metadata.
10. Add `CsvImport::Approval`/`CsvImport::Rejection` models and approve/reject behavior for imports.
11. Add approval processing for the first import type.
12. Add tests for upload attachment, generic create Turbo response, extraction job, validation job, Turbo Stream broadcasts, row hashing, duplicate detection, approval, rejection, raw download, and approval processing.
