# Marketplace admin final verification

## Navigation correction — 16 October 2026

The subsequent [workspace navigation configuration](workspace-navigation.md)
moves Products, Categories, Allergens and Menus into the main editor/admin sidebar
and reserves Admin for user management. Catalogue URLs are now outside `/admin`.
The full Rails regression suite passed **764 tests, 3,977 assertions**, with zero
failures or errors. RuboCop passed for all nine changed Ruby files; ArchSpec passed
for 206 files with its existing analysis gaps. The checkpoint and browser evidence below describe the earlier
implementation; they do not constitute a new browser check of this correction.

## Earlier verification checkpoint

Verified 16 October 2026 against the confirmed
[requirements](marketplace-admin-requirements.md),
[Figma coverage](marketplace-figma-coverage.md) and
[feature tracker](admin-implementation.md). Runtime source checkpoint: `f547006`.
The user confirmed that Orders is a deferred destination for this build.

## Acceptance gates

| Gate | Evidence |
| --- | --- |
| Functional admin workflows | Catalogue controllers, domain models, policies and presenters inspected; complete Rails suite and browser sweep passed. Scope details below. |
| Actions and authorization | View-facing actions present controls; controllers enforce policies and call domain methods. Availability repeats eligibility checks inside the transaction. Policy/request tests cover guests, viewers, editors/admins, foreign records and revoked access. |
| Direct model and regression tests | `bin/rails test`: **762 tests, 3,932 assertions**, zero failures/errors/skips, seed 43653. Includes direct tests for new content models, forms, publication, availability, history and rollback. |
| RuboCop | `bin/rubocop`: **403 files, no offenses**. Configuration unchanged; no catalogue suppression comments added. |
| Architecture | `bin/archspec check`: **206 files, 268 constants, 7,310 facts**, passed. Analysis gaps: 208 unresolved references, 3 dynamic features, 3,129 unknown-receiver calls and 1 RubyDEX DynamicAncestor diagnostic. Passing does not mean those analysis gaps disappear. |
| Migrations | All application migrations are up through `20261016000400` in the isolated development database. Cache/queue/cable databases use their framework schema version 001. Test databases are prepared; no pending application schema change was introduced by the final navigation fixes. |
| Browser workflows | **12 tests, 291 assertions**, zero failures/errors/skips, seed 61106. Covers desktop 1440px and mobile 390px; details below. |
| Visual comparison | Figma contexts/renders inspected throughout implementation; refreshed representative screenshots reviewed at final verification. Remaining differences are listed below. |
| Feature tracking and commits | Tracker is complete. Features and subsequent fixes are committed individually; final runtime change is `f547006`. |

## Requirement audit

Paths below are relative to `test/`; related implementation lives under the
corresponding `app/models`, `app/controllers`, `app/actions` and `app/policies`.

| Requirement group | Authoritative coverage checked |
| --- | --- |
| Bucket ownership, one currency, classifier isolation | `models/product/draft_test.rb`, `models/product/variant_draft_test.rb`, `models/menu_section/draft_test.rb`, classifier model/policy/request tests; bucket-scoped controller lookups and forms. No Site model introduced. |
| Required product/default variant, optional images/descriptions, zero/nonnegative prices | `models/product_test.rb`, `models/variant_test.rb`, `models/product/draft_test.rb`, `models/product/variant_draft_test.rb`; invalid creation and operational-state failures roll back the aggregate. |
| Copying and default unavailable state | `models/product/copy_test.rb`, `models/product/variant_draft_test.rb`, `controllers/products/copies_controller_test.rb`; independent immutable content, copied classifiers/images, no copied availability/publication/placements. |
| Categories and allergens, retained archived assignments | Category/allergen controller and policy tests; Product::Draft, VariantDraft and VariantChanges tests reject new foreign/archived references while preserving or removing existing assignments. |
| Variant allergens, source selection, bulk editing | `models/product/variant_changes_test.rb`, `models/product/variant_draft_test.rb`, `controllers/products_controller_test.rb`; independent per-variant assignments and attributed bulk events. |
| Live allergen warning | `models/catalogue/allergen_warnings_test.rb`, `controllers/allergen_warnings_test.rb`; wording/assignment changes, affected products, product republication resolution, menu republication non-resolution, archive/live filtering and staff exclusion. |
| Menu/section presentation, images, ordered placements and duplicate indicators | `models/menu/draft_test.rb`, `models/menu/structure_test.rb`, `models/menu_section/draft_test.rb`, `models/menu_section/placements_test.rb`, `controllers/menus_controller_test.rb`; duplicate-in-section rejection and shared placement indicators. |
| Product publication and separate live content | `models/product/publication_test.rb`, `models/catalogue/published_product_test.rb`, product publication/reversion request tests; published prices/allergen wording/images/variant order, no implicit availability changes, stale review rejection and live-reference unpublish restriction. |
| Menu publication and preview | `models/menu/publication_test.rb`, `models/menu/preview_test.rb`, menu publication/reversion request tests; unpublished blockers, empty draft sections omitted, published product versions, images and independently live availability. |
| Atomic single live menu | Bucket row locking plus partial unique database index `one_active_menu_per_bucket`; `models/menu/concurrent_publication_test.rb` uses concurrent connections and proves one successful publication and one stale review. Rollback test verifies both release states and events. |
| Revert scope and archive preservation | Product/menu publication tests cover latest published version, unpublished releases, preserved availability, retained history, archived references, forbidden never-published revert and preserved separate publication scopes. Confirmation request tests cover impact and notices. |
| Archive and restore lifecycle | `models/catalogue/archive_lifecycle_test.rb`, `models/recording/catalogue_editing_test.rb`, `controllers/catalogue_archives_test.rb`; immediate hiding/withdrawal, empty-container filtering, unavailable restoration, retained snapshots, archived parent filtering and menu unpublication. |
| History and comparisons | Classifier/product/menu controller tests; Timeline, RecordableDiff, PublicationDiff and helper tests; actor/time, descendants, historical names, scalar/relationship/image changes, availability transitions, published snapshots and menu replacement names. No arbitrary historic restoration control. |
| Overview and availability | `models/catalogue/overview_test.rb`, `models/catalogue/availability_test.rb`, availability policy/action/request tests; published visible variants only, deduplication across sections, individual/bulk explicit states, idempotency, rollback and fresh authorization under lock. |
| Navigation, Orders and landing | Order policy/request tests, `integration/modern_navigation_test.rb`, sessions/invitations/registration/bucket-switch tests; correct links/roles, deferred GET-only Orders, Overview defaults and retained return destinations. Articles removed from sidebars; existing editorial URLs remain available. |
| Stale editing, validation and feedback | Recording::CatalogueEditing, product/menu drafts/publications and controller tests cover stale saves/reviews, invalid values, rollback, retained form values and empty/error states. |

## Browser and visual evidence

The final sweep ran these ignored local system-test files together:

`tmp/{catalogue,publication,menu,menu_publication,archive,copy,catalogue_filters,allergen_warning,overview,history,history_audit,navigation}_visual_test.rb`

It exercises creation, product publication/revert/unpublish, menu editing and
publication/blockers/revert, archive/restore, copying, filters, allergen warning
resolution, individual/bulk Turbo availability, empty states, history disclosures,
menu replacement context, Orders and responsive navigation. Screenshots are local
ignored artifacts in `tmp/catalogue-*.png`, `tmp/history-*.png`,
`tmp/*navigation-*.png` and `tmp/orders-*.png`, not committed production assets.

Figma reference coverage is linked in the design coverage document. Representative
references inspected include Products `4:101`, product editor `4:175`, Overview
`3:47`, history `14:839`, mobile navigation `14:1044`, and Orders `44:168`, plus
the classifier, menu, archive, publication and warning references recorded in the
feature checkpoints. Final refreshed renders reviewed include product editor,
mobile publication/archive confirmations, allergen warnings and mobile Overview;
history, Orders and navigation renders were also reviewed in their final feature
checks. All browser checks assert no horizontal overflow on their sampled pages.

Remaining visual differences, rather than functional blockers:

- Inter is preferred in the font stack but not bundled; the environment uses a
  system fallback, changing text metrics.
- Currency is shown explicitly as the bucket code (for example GBP), whereas
  some Figma samples use £.
- History comparisons expand inline rather than opening a separate comparison
  screen. Actor/time metadata occupies an additional line; rows can be taller.
- Mobile navigation uses an inline native disclosure within the compact header,
  rather than a separate full navigation screen. Active navigation is retained.
- Warning and confirmation text expands for actual affected records. Allergen
  warnings show before/after wording, so they can exceed the compact sample height.
- Native file/select controls, explicit order inputs and disclosure sections
  retain browser styling in places. Bulk allergen editing occupies a full-width
  panel below the product/variant columns.
- User identity shows the current person's name without the sample role suffix.
  Product imagery is supplied by uploads; Figma sample artwork is not seeded as
  real catalogue data. No required static Figma asset was identified in these screens.

The headless Chrome harness intermittently ignores native pointer clicks after
device emulation; affected interactions use DOM activation. Form input, server
mutations, Turbo responses and resulting state are still checked. The combined
sweep initially exposed shared viewport timing in the test harness; it passed
after explicitly resetting/waiting for the navigation breakpoint state. This is
not a claim of exhaustive browser or accessibility compatibility testing.

## Environment and reproducibility

Run commands from `rails-app` using:

```sh
docker compose -p marketplace-admin -f docker-compose.yml -f /tmp/marketplace-admin-compose.yml exec web bin/rails test
docker compose -p marketplace-admin -f docker-compose.yml -f /tmp/marketplace-admin-compose.yml exec web bin/rubocop
docker compose -p marketplace-admin -f docker-compose.yml -f /tmp/marketplace-admin-compose.yml exec web bin/archspec check
docker compose -p marketplace-admin -f docker-compose.yml -f /tmp/marketplace-admin-compose.yml exec web bin/rails db:migrate:status
```

The temporary override clears published web/postgres/mailcatcher ports and reuses
only the gem volume. Database and network are isolated. The ordinary
`rails-app-web-1` container was replaced by a different checkout during this task;
its test output was discarded and its data was not modified. Port 3000 still
belongs to that other checkout. This verification does not deploy the app or
replace that server. See the tracker for the environment correction history.

Orders storage/listing/processing, customer checkout, arbitrary history rollback
and advanced collaboration remain intentionally deferred. No outstanding blocker
was found for the agreed admin implementation scope.
