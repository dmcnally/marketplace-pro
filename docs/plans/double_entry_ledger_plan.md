# Double Entry Ledger Plan

## Goal

Add a double entry ledger as an immutable list of financial facts. Each fact is a ledger entry with:

- a positive integer amount in minor currency units
- a currency code
- a side, either debit or credit
- an account
- a ledger book within a bucket
- a required group that records the atomic posting event

Entries are never edited or deleted. Corrections are represented by new reversing entry groups.

## Core Decisions

1. Keep the ledger outside the `Recording` delegated-type content model.
   The ledger is operational financial state, not editable content. It should be scoped to a `Ledger::Book` within a `Bucket`, and individual lines may optionally be attributed to a `Person`.

2. Use `ledger_entry_groups` as the balancing boundary inside one ledger book.
   A group is the journal entry. It can contain many debit lines and many credit lines.

3. Store debits and credits as positive values.
   `ledger_entries.amount_minor` is always greater than zero. The sign is derived from `side` only when summing.

4. Enforce balance within one currency.
   A group has one currency, and every entry in the group must use that currency. The group is valid only when:

   ```sql
   SUM(CASE side WHEN 'debit' THEN amount_minor ELSE -amount_minor END) = 0
   ```

5. Do not store mutable balances in v1.
   Balances are derived from immutable entries. Cached balances can be added later as a projection if query volume requires it.

## Proposed Schema

### `ledger_books`

Ledger books define the financial boundary for accounts, posting groups, entries, balances, and rollups. A book belongs to a bucket and has a polymorphic owner, such as a `Tronc`.

Columns:

- `bucket_id`, required foreign key
- `owner_type`, required string
- `owner_id`, required bigint
- `name`, required
- `active`, required boolean, default true
- `created_at`, `updated_at`

Indexes:

- unique index on `[owner_type, owner_id]`
- unique index on `[bucket_id, name]`
- index on `[bucket_id, owner_type, owner_id]`

Rules:

- A ledger book belongs to exactly one bucket.
- A ledger book has exactly one owner.
- Ledger posting happens inside a ledger book, not directly against a bucket or owner object.
- The book `bucket_id` must match the owner's bucket when the owner is bucket-scoped, such as `Tronc`.
- Ledger books may be deactivated but should not be destroyed once ledger facts exist.
- Only `ledger_books` uses the polymorphic owner relation. Core financial tables reference `ledger_book_id` directly.

### `troncs`

Troncs define one possible owner of a ledger book.

Columns:

- `bucket_id`, required foreign key
- `name`, required
- `active`, required boolean, default true
- `created_at`, `updated_at`

Indexes:

- unique index on `[bucket_id, name]`

Rules:

- A tronc belongs to exactly one bucket.
- A tronc owns one ledger book.
- A tronc may be deactivated but should not be destroyed once its ledger book has facts.

### `ledger_accounts`

Accounts define where entries post.

Columns:

- `bucket_id`, required foreign key
- `ledger_book_id`, required foreign key
- `name`, required
- `code`, required, unique per ledger book
- `currency`, required string, length 3
- `category`, required string enum: `asset`, `liability`, `equity`, `income`, `expense`
- `normal_side`, required string enum: `debit`, `credit`
- `active`, required boolean, default true
- `created_at`, `updated_at`

Indexes:

- unique index on `[ledger_book_id, code]`
- index on `[bucket_id, ledger_book_id]`
- index on `[ledger_book_id, currency]`
- index on `[ledger_book_id, category]`

Rules:

- Accounts may be deactivated but should not be destroyed once entries exist.
- Accounts are currency-specific.
- Account `bucket_id` must match the account ledger book's bucket.
- `normal_side` is reporting metadata for interpreting balances. It must not prevent posting either debit or credit lines to the account.
- If account edits are risky for auditability, limit mutable fields to `name` and `active`.
- `currency` is stored as an uppercase 3-character code.

### `ledger_entry_groups`

Groups represent atomic balanced posting events.

Columns:

- `bucket_id`, required foreign key
- `ledger_book_id`, required foreign key
- `created_by_id`, optional foreign key to `people`
- `posted_at`, required datetime
- `currency`, required string, length 3
- `description`, optional text
- `reference`, optional string for external-facing IDs
- `source_type`, optional string
- `source_id`, optional bigint
- `idempotency_key`, optional string
- `reverses_ledger_entry_group_id`, optional self-reference
- `created_at`

Indexes:

- index on `[bucket_id, ledger_book_id, posted_at]`
- index on `[source_type, source_id]`
- unique partial index on `[ledger_book_id, idempotency_key]` where `idempotency_key IS NOT NULL`
- index on `reverses_ledger_entry_group_id`

Rules:

- Groups are immutable after creation.
- Every committed group must have at least two entries.
- Every committed group must have at least one debit and one credit.
- Every committed group must balance to zero.
- Every entry in the group must use the group's currency.
- Group `bucket_id` must match the ledger book's bucket.
- `currency` is stored as an uppercase 3-character code.

### `ledger_entries`

Entries are the immutable ledger facts.

Columns:

- `ledger_entry_group_id`, required foreign key
- `bucket_id`, required foreign key
- `ledger_book_id`, required foreign key
- `ledger_account_id`, required foreign key
- `side`, required string enum: `debit`, `credit`
- `amount_minor`, required bigint
- `currency`, required string, length 3
- `person_id`, optional foreign key to `people`
- `memo`, optional text
- `position`, required integer
- `created_at`

Indexes:

- index on `[ledger_book_id, ledger_account_id, created_at]`
- index on `[ledger_entry_group_id, position]`, unique
- index on `[ledger_book_id, currency, created_at]`
- index on `[ledger_book_id, person_id, created_at]`
- index on `[currency]`

Database checks:

- `amount_minor > 0`
- `side IN ('debit', 'credit')`
- `currency = UPPER(currency)`
- `char_length(currency) = 3`

Rules:

- Entries are immutable after creation.
- `bucket_id` must match the entry ledger book's bucket, the group bucket, and the account bucket. Prefer composite foreign keys where Rails/Postgres support is acceptable; otherwise enforce this with a database trigger plus model validation.
- `ledger_book_id` must match both the group ledger book and the account ledger book.
- `currency` must match both the group currency and the account currency.
- `person_id` records who the entry line is about, not who created the posting. The posting actor remains `ledger_entry_groups.created_by_id`.

## Database Balance Enforcement

Application validation is useful but not enough for a ledger. The database should reject imbalanced commits.

Implement a PostgreSQL deferred constraint trigger:

1. Trigger on insert into `ledger_entry_groups`.
2. Trigger on insert into `ledger_entries`.
3. The trigger is `DEFERRABLE INITIALLY DEFERRED`, so a service can create the group and all entries in one transaction before validation runs.
4. At commit, validate each affected group:
   - entry count is at least 2
   - both debit and credit sides are present
   - signed sum is zero
   - every entry's bucket matches its ledger book, group, and account
   - every entry's ledger book matches its group and account
   - every entry's currency matches its group and account

Also add database immutability triggers for `UPDATE` and `DELETE` on `ledger_entry_groups` and `ledger_entries`. Rails model callbacks are still useful, but database protection is the audit boundary.

## Rails Models

Add a `Tronc` domain model, and use a `Ledger` namespace for ledger-specific models:

- `Tronc`
- `Ledger::Book`
- `Ledger::Account`
- `Ledger::EntryGroup`
- `Ledger::Entry`
- `Ledger::Money`
- `Ledger::PostingLine`

Associations:

- `Bucket has_many :troncs`
- `Bucket has_many :ledger_books, class_name: "Ledger::Book"`
- `Bucket has_many :ledger_accounts`
- `Bucket has_many :ledger_entry_groups`
- `Bucket has_many :ledger_entries`
- `Tronc belongs_to :bucket`
- `Tronc has_one :ledger_book, as: :owner, class_name: "Ledger::Book"`
- `Ledger::Book belongs_to :bucket`
- `Ledger::Book belongs_to :owner, polymorphic: true`
- `Ledger::Book has_many :ledger_accounts, class_name: "Ledger::Account"`
- `Ledger::Book has_many :ledger_entry_groups, class_name: "Ledger::EntryGroup"`
- `Ledger::Book has_many :ledger_entries, class_name: "Ledger::Entry"`
- `Ledger::Account belongs_to :bucket`
- `Ledger::Account belongs_to :ledger_book, class_name: "Ledger::Book"`
- `Ledger::EntryGroup belongs_to :bucket`
- `Ledger::EntryGroup belongs_to :ledger_book, class_name: "Ledger::Book"`
- `Ledger::EntryGroup belongs_to :created_by, class_name: "Person", optional: true`
- `Ledger::EntryGroup has_many :entries, class_name: "Ledger::Entry"`
- `Ledger::Entry belongs_to :entry_group, class_name: "Ledger::EntryGroup"`
- `Ledger::Entry belongs_to :account, class_name: "Ledger::Account"`
- `Ledger::Entry belongs_to :ledger_book, class_name: "Ledger::Book"`
- `Ledger::Entry belongs_to :person, optional: true`

Include the existing `Immutable` concern in `Ledger::EntryGroup` and `Ledger::Entry`.

### Value Objects

Use concrete value objects for posting input. Do not pass free-form hashes into the ledger writer.

`Ledger::Money` is an immutable non-persisted value object:

- `amount_minor`, required positive integer
- `currency`, required uppercase 3-character code
- rejects arithmetic or comparison across different currencies

`Ledger::PostingLine` is an immutable non-persisted value object:

- `account`, required `Ledger::Account`
- `side`, required, either `debit` or `credit`
- `money`, required `Ledger::Money`
- `person`, optional `Person`
- `memo`, optional string
- exposes `amount_minor` and `currency` from `money`
- validates only that `side` is `debit` or `credit`; it does not compare `side` with the account's `normal_side`
- provides factory methods for intent clarity:
  - `Ledger::PostingLine.debit(account:, money:, person: nil, memo: nil)`
  - `Ledger::PostingLine.credit(account:, money:, person: nil, memo: nil)`

## Posting API

Create one internal service object as the only supported writer:

- `Ledger::PostingGroup.call(ledger_book:, lines:, posted_at:, created_by: nil, description: nil, reference: nil, source: nil, idempotency_key: nil)`

This is an internal application API only. Do not add RESTful routes, controllers, or public request endpoints for posting ledger entries in v1. Domain workflows inside the app should call the service directly.

Example input:

```ruby
lines = [
  Ledger::PostingLine.debit(
    account: cash_account,
    money: Ledger::Money.new(amount_minor: 10_00, currency: "USD"),
    person: employee,
    memo: "Cash received"
  ),
  Ledger::PostingLine.credit(
    account: revenue_account,
    money: Ledger::Money.new(amount_minor: 10_00, currency: "USD"),
    person: employee,
    memo: "Revenue recognized"
  )
]

Ledger::PostingGroup.call(
  ledger_book: tronc.ledger_book,
  lines: lines,
  posted_at: Time.current,
  description: "Record sale"
)
```

Service responsibilities:

- wrap the write in a single database transaction
- accept only `Ledger::PostingLine` instances
- derive the bucket from the ledger book
- derive the group currency from the line money objects
- reject mixed-currency line sets
- populate each entry's currency from its line money
- reject entries for accounts from a different ledger book
- reject entries for accounts from a different bucket than the ledger book
- reject account and line currency mismatches
- preserve optional line person attribution on each persisted entry
- validate balance before insert for clear Rails errors
- rely on the deferred database trigger as the final invariant
- support idempotency by returning the existing group when the same `[ledger_book_id, idempotency_key]` already exists

Do not expose general `create`, `update`, or `destroy` paths for entries.
Do not expose ledger posting through resourceful controllers.

## Reading API

Add query methods or query objects:

- account balance as of a time
- person-attributed entries and balances, for workflows like employee tip allocation
- account ledger entries ordered by `posted_at`, group id, and position
- trial balance for a ledger book, naturally scoped by account currency
- group detail view for audit/debugging

Balance formula:

```sql
SUM(
  CASE ledger_entries.side
  WHEN 'debit' THEN ledger_entries.amount_minor
  ELSE -ledger_entries.amount_minor
  END
)
```

For presentation, account categories decide whether a positive signed balance is shown as debit-normal or credit-normal.

## Corrections and Reversals

Never mutate a mistaken group. Create a new group that reverses it:

- each original debit becomes a credit
- each original credit becomes a debit
- amounts and currencies stay the same
- `reverses_ledger_entry_group_id` points at the original group

Optional later behavior:

- prevent reversing the same group more than once with a unique index on `reverses_ledger_entry_group_id`
- add a replacement group that links to the reversal for audit chains

## Tip Distribution Batches

For splitting tips across many employees, prefer multiple posting groups tied together by a domain batch instead of one large group.

Proposed shape:

- `TipDistributionRun` belongs to a `Ledger::Book`.
- For tronc workflows, the run uses `tronc.ledger_book`.
- Each employee allocation creates its own balanced `Ledger::PostingGroup`.
- The employee is attributed on the relevant `Ledger::PostingLine`, which persists to `ledger_entries.person_id`.
- All groups in the run share `source_type: "TipDistributionRun"` and the run id as `source_id`.
- The batch/domain object validates the aggregate rule that total allocated equals total tips being distributed.

This keeps each employee allocation independently reversible while the batch records the wider distribution context.

## Implementation Steps

1. Add migrations for `troncs`, `ledger_books`, `ledger_accounts`, `ledger_entry_groups`, and `ledger_entries`.
2. Add database check constraints and indexes.
3. Add deferred balance validation trigger.
4. Add database immutability triggers for groups and entries.
5. Add `Tronc`, `Ledger::Book`, `Ledger::Account`, `Ledger::EntryGroup`, and `Ledger::Entry` models.
6. Add `Ledger::Money` and `Ledger::PostingLine` immutable value objects.
7. Wire bucket, owner, and ledger book associations.
8. Add `Ledger::PostingGroup` service.
9. Add reversal service if needed immediately: `Ledger::ReverseEntryGroup`.
10. Add query objects for balances and account activity.
11. Confirm no posting routes/controllers are added in v1.
12. Add model, value object, and service tests.

## Test Plan

Migration/database tests:

- rejects zero and negative `amount_minor`
- rejects invalid `side`
- rejects invalid currency format
- rejects a group with only debits
- rejects a group with only credits
- rejects an imbalanced group
- rejects a multi-currency group
- rejects entry/book/group/account bucket mismatches
- rejects entry/group/account ledger book mismatches
- rejects entry/group/account currency mismatches
- rejects update and delete for committed groups and entries

Service tests:

- creates a balanced group with multiple debit and credit entries
- stores all amounts as positive integers
- accepts concrete posting line objects instead of hashes
- returns an existing group for duplicate idempotency key
- derives bucket from the ledger book
- rejects cross-book accounts
- rejects cross-bucket accounts for the ledger book
- rejects cross-currency accounts
- rejects mixed-currency line sets
- persists optional person attribution per line
- rejects imbalanced input before commit
- creates a reversal group with opposite sides
- is exercised directly as an internal service, not through a controller

Value object tests:

- `Ledger::Money` rejects non-positive and non-integer amounts
- `Ledger::Money` normalizes and validates currency
- `Ledger::PostingLine` rejects sides other than `debit` or `credit`
- `Ledger::PostingLine` permits debit or credit for any account, regardless of account `normal_side`
- `Ledger::PostingLine` exposes amount and currency from its money object
- `Ledger::PostingLine` carries optional person attribution
- `Ledger::PostingGroup` rejects plain hashes and other non-line inputs

Query tests:

- calculates account balance from entries
- calculates trial balance per ledger book and currency
- respects `posted_at` cutoffs
- orders entries deterministically by `posted_at`, group id, and position

## Resolved Questions

1. Currency is stored directly as an uppercase 3-character code on accounts, groups, and entries. No separate currency metadata table is planned for v1.
2. Account-level overdraft rules are out of scope for now. The ledger may record any balanced fact.
3. Ledger groups stay internal-only for now. Timeline events can be projected from ledger facts later.
4. Posting happens for a `Ledger::Book` inside a `Bucket`. The posting service accepts `ledger_book:` and derives `bucket` from it.
5. A `Ledger::Book` has a polymorphic owner. A `Tronc` owns one ledger book for tronc-specific posting.

## Open Questions

1. Should account codes be user-defined, seeded defaults, or both?
2. Which domain actions will be the first sources that post into the ledger?
