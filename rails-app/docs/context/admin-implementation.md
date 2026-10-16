# Admin implementation tracker

Scope: [confirmed requirements](marketplace-admin-requirements.md) and
[Figma coverage](marketplace-figma-coverage.md). Each feature is committed after
implementation and focused verification. Design coverage alone is not completion.

## Features

- [x] Categories: create/edit, validation, archive/restore, history, stale saves, permissions.
- [ ] Allergens: bucket-owned management, archive/restore, history and permissions.
- [ ] Products and variants: immutable content, images, prices, ordering, categories, copied/bulk allergen assignments.
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
Runtime visual verification remains blocked: the connected browser inventory is
empty; the container Chrome symlink points to an unavailable `/resources` binary.
Do not treat design-context inspection as a rendered comparison. Navigation is
temporarily limited to implemented routes; the full main/admin split remains a
separate pending feature. Product counts await product assignments.

Orders processing and arbitrary historical restore remain deferred by the
confirmed requirements; existing functionality remains available.
