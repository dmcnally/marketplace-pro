# Admin implementation tracker

Scope: [confirmed requirements](marketplace-admin-requirements.md) and
[Figma coverage](marketplace-figma-coverage.md). Each feature is committed after
implementation and focused verification. Design coverage alone is not completion.

## Features

- [x] Categories: create/edit, validation, archive/restore, history, stale saves, permissions.
- [x] Allergens: bucket-owned management, archive/restore, history and permissions.
- [x] Products and variants: immutable content, images, prices, ordering, categories, copied/bulk allergen assignments.
- [ ] Product copying and catalogue filters: unpublished copies, category/publication filters, archive listing.
- [ ] Product publication: snapshots, impact confirmation, unpublished changes, unpublish restrictions, revert.
- [ ] Menus: presentation/images, ordered sections and placements, duplicate indicators, draft preview.
- [ ] Menu publication: blockers, atomic replacement, snapshots, stale confirmation, unpublish/revert.
- [ ] Archive lifecycle: live filtering, preserved snapshots, unavailable restoration, menu unpublication.
- [ ] Overview: live published menu, variant and bulk availability, per-record events, staff permissions.
- [ ] Live allergen warnings: affected products, assignment/content changes, correct resolution.
- [ ] History: actor/time and before/after comparisons including relationships and variant events.
- [ ] Navigation and Orders: main/admin split, mobile navigation, read-only bucket orders.
- [ ] Final verification: focused/full tests, RuboCop without suppressions, Archspec, desktop/mobile visual comparison.

## Evidence and remaining work

Initial inspection: existing Rails application has editorial/admin infrastructure
and Modern shared styles, but no marketplace domain tables or routes. Working
tree was clean. Figma Products frame `4:101` inspected with design context and
screenshot; current design uses navy sidebar, blue controls, 16px spacing and
9px control radii. Feature-specific screens will be inspected before UI work.

### Categories

Implemented immutable category content under bucket-owned Recordings, editor/admin
management, policy-backed controls, scoped routes, validation, archive/restoration
events, stale-save protection, and actor/time/before-after history. Generic diff
access also enforces the category policy. No destructive category route exists.

Migration `20261016000000` applied to development. The database already contains
legacy `sites`, `categories`, and `category_contents` tables from migrations absent
from this checkout. They were preserved. New content uses `catalogue_categories`;
schema.rb was generated with only those three unrelated legacy tables excluded.
Future schema dumps against this development database need the same exclusions.

Focused workflow/policy checks: 8 tests, 84 assertions passed. Full regression:
576 tests, 1,830 assertions passed before adding action-presenter coverage.
Full RuboCop and Archspec passed (Archspec reports existing analysis gaps).

Design context and screenshots reviewed for categories `4:2` and edit `4:67`.
The new shell/components follow their dimensions, tokens and field treatment.
Initial connected-browser verification was unavailable; later headless Docker
verification succeeded (see below). Navigation is
temporarily limited to implemented routes; the full main/admin split remains a
separate pending feature. Product counts await product assignments.

Orders processing and arbitrary historical restore remain deferred by the
confirmed requirements; existing functionality remains available.

### Allergens

Implemented bucket-owned immutable allergen content, create/edit validation,
archive/restore, stale-save rejection, policy-backed controls, read-only history
and before/after comparison. Migration `20261016000100` applied successfully.
Category/allergen controls share the shell and editing lifecycle; each resource
has explicit policies and controller scopes. Access-denied pages now explain the
required role. Focused tests: 17 tests, 175 assertions passed; RuboCop clean,
Archspec passed. Category presenter/navigation checks also passed: 29 tests,
181 assertions.

Figma allergen list `7:85` and edit `7:144` inspected via design context and
screenshots. Affected-product warnings depend on product publication and remain
in the separate pending feature above; no sample affected products are displayed.
The later headless verification below covers the rendered allergen list.

### Products and variants

Migration `20261016000200` applied: product/variant immutable content, separate
variant availability rows (default false), and bucket currency (default GBP).
Implemented product creation with a required first variant, immutable editing,
nonnegative prices, optional version-preserving images, category selection,
variant copying from a selected source, per-variant allergens, bulk assignment
and removal, ordering, and product history including variant changes. History
comparisons resolve relationship IDs to names at the event time. New assignments
reject retired/foreign classifiers; retained archived assignments remain valid.
Workspace locks serialize classifier retirement with assignment changes.

Product workflow tests: 8 tests, 91 assertions passed, including image retention
and removal. Full regression: 596 tests, 2,049 assertions passed. After the final
locking adjustment, 22 focused tests with 229 assertions passed; full RuboCop
passed (310 files), and Archspec passed. Design
context/screenshot for product editor `4:175` inspected in addition to list
`4:101`; forms use the two-column editor layout and shared controls. Publication,
copying, filters and archive actions are still pending and are not represented as
working controls.

### Rendered verification

Docker's `/usr/bin/chrome` is available (the initial assumption about its symlink
was incorrect). Selenium Manager resolves its driver. A temporary system test at
`tmp/catalogue_visual_test.rb` passed 21 assertions: category creation through the
browser and no horizontal overflow on category/allergen lists and product/variant
editors at 1440px and 390px. Screenshots `tmp/catalogue-*.png` were inspected
against the retrieved Figma renders; they are ignored local artifacts.

Use a 1600×1200 Chrome window before CDP viewport emulation to avoid screenshot
surface clipping. Perform keyboard workflow checks before toggling mobile device
emulation: Chrome 141 lost Selenium input after toggling emulation. This was
isolated to the harness; the initial desktop form workflow passes.

Remaining visual differences: full navigation/mobile drawer is pending; Inter
is not bundled; publication controls and warnings await their domain features;
product bulk-allergen controls currently span a full row until the lifecycle
panel is added. Archive, history, validation and all final lifecycle states still
need final screenshot coverage. No static Figma image assets were present in
the inspected catalogue screens.
