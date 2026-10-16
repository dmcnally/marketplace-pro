# Admin implementation tracker

Scope: [confirmed requirements](marketplace-admin-requirements.md) and
[Figma coverage](marketplace-figma-coverage.md). Each feature is committed after
implementation and focused verification. Design coverage alone is not completion.
Keep commits to small, complete workflows; finish and commit the current workflow
before starting another. The user explicitly requested shorter gaps between commits.

## Features

- [x] Categories: create/edit, validation, archive/restore, history, stale saves, permissions.
- [x] Allergens: bucket-owned management, archive/restore, history and permissions.
- [x] Products and variants: immutable content, images, prices, ordering, categories, copied/bulk allergen assignments.
- [x] Product copying: independent unpublished copies with unavailable variants.
- [x] Catalogue filters: category and publication filters, accurate draft prices/counts and publication labels.
- [x] Product publication: snapshots, impact confirmation, unpublished changes, unpublish restrictions, revert.
- [x] Menus: presentation/images, ordered sections and placements, duplicate indicators, draft preview.
- [x] Menu publication: blockers, atomic replacement, snapshots, stale confirmation, unpublish/revert.
- [x] Archive lifecycle: live filtering, preserved snapshots, unavailable restoration, menu unpublication.
- [ ] Overview: live published menu, variant and bulk availability, per-record events, staff permissions.
- [ ] Live allergen warnings: affected products, assignment/content changes, correct resolution.
- [ ] History: actor/time and before/after comparisons including relationships and variant events.
- [ ] Navigation and Orders: main/admin split, mobile navigation, read-only bucket orders.
- [ ] Final verification: focused/full tests, RuboCop without suppressions, Archspec, desktop/mobile visual comparison.

## Evidence and remaining work

Catalogue filters: category and publication state combine with literal name
search. Published, unpublished, never-published and unpublished-change filters
use the actual publication lifecycle. Archived categories remain filterable for
retained assignments; invalid/foreign filters produce no results and clear
feedback. Product rows show active draft variant counts and minimum prices,
excluding variants outside the current draft order. Search and selection values
persist, Clear filters resets them, and existing management authorization applies.

Verification: 726 tests / 3,421 assertions passed; full RuboCop clean (382 files),
Archspec passed (196 files; analysis gaps remain). No migration needed.
The Figma Products `4:101` context/render inspected during the preceding workflow
provided the filter/record layout. `tmp/catalogue_filters_visual_test.rb` passed
15 assertions for combined form submission, clearing, prices/states and desktop/
mobile overflow. Both `tmp/catalogue-filters-*.png` renders were inspected; the
dropdowns use shared colors, radii and focus states. Functional select controls
and explicit submit/reset buttons make the filter panel taller than Figma's
static summary. Currency is shown explicitly as the bucket's code. Allergen
warnings and the Overview link remain in their separately tracked workflows.

Product copying: a named copy form creates independent immutable product and
active variant content in draft order, including image, categories, prices and
allergens. Copies have no publication or menu placements; availability starts
false. Archived/out-of-order variants are excluded. Archived classifier
assignments block copying with guidance to restore or remove them, rather than
silently dropping allergen information or making forbidden new assignments.
Source revisions are checked under the bucket lock. Copied product/variant
events identify their source, and failures roll back all partial content/events.
Policies restrict copying to editors/admins and active products in their bucket.

Verification: 721 tests / 3,349 assertions passed; full RuboCop clean (380 files),
Archspec passed (195 files; reported analysis gaps remain). No migration needed.
Figma product editor `4:175` and copy form `45:601` inspected. Temporary Chrome
test `tmp/copy_visual_test.rb` passed 14 assertions, including actual copy
submission, unavailable/unpublished state and no overflow at 1440px/390px.
Both `tmp/catalogue-copy-*.png` renders were visually inspected against the copy
design. The editor's copy control currently occupies its own lifecycle panel;
the final editor layout pass will group lifecycle controls as shown in Figma.
Existing font/navigation differences and native headless input limitations remain.

Archive lifecycle: product/variant/menu archive confirmations, archive lists and
restoration are policy-backed and stale-protected. Product archiving withdraws all
variant availability with an attributed event for each changed variant. Variant
archiving leaves siblings unchanged. Live-menu archiving unpublishes in the same
transaction. Failed archives roll back availability, release state and events.
Restoration never enables availability or publishes a menu. Published snapshots,
immutable content and history are retained. `Catalogue::LiveMenu` reads published
structure and current product releases, filters archived products/variants and
empty containers, and reveals eligible restored content without republishing.
The upcoming Overview uses this reader; its controls are still pending.

Full suite: 712 tests / 3,245 assertions passed. RuboCop clean (376 files),
Archspec passed (193 files; reported analysis gaps remain). No schema changes
were needed; checkout migrations remain applied through `20261016000400`.
Direct model tests cover filtering, restoration, draft-only variants, stale
publication, rollback, availability events and preservation of snapshots.
Integration/policy/action coverage checks ownership, viewer denial, stale/missing
revisions, confirmation links, archive listing and restoration.
Temporary Chrome test `tmp/archive_visual_test.rb` passed 37 assertions including
archive/restore actions and five screens at 1440px/390px without overflow.
Representative product/variant confirmations and archive lists were inspected
against Figma `14:767`, `45:473`, `48:773`. Product and variant confirmations are
separate pages instead of the combined showcase. The menu list currently says
history retained without the design's last-publication date. Shared navigation
and font differences remain tracked below. Native headless click limitations
persist; the browser test dispatched DOM clicks through real forms.

Menu publication: immutable presentation/structure snapshots, named unpublished
product blockers, atomic replacement of the live menu, impact confirmation,
unpublish, and revert to the last publication. Product publications and live
availability remain independent. Empty sections are omitted from live sections;
the snapshot separately retains their draft structure for comparison and revert.
Stale confirmations cover draft changes, product dependencies and live-menu
replacement. Direct model tests cover rollback, archived references and two
simultaneous confirmations on separate database connections: one succeeds and
the other is rejected as stale. Controller, policy and action tests cover access
and confirmation flows. Product unpublication is blocked by every live placement.

Verification: full suite 695 tests / 3,008 assertions, full RuboCop clean (370
files), Archspec passed (189 files; analysis gaps remain). All checkout migrations
are applied through `20261016000400`; this feature needs no new migration.
Temporary Chrome test `tmp/menu_publication_visual_test.rb` passed 38 assertions
for replacement, revert, unpublish, named blockers and overflow at 1440px/390px.
Eight `tmp/catalogue-menu-{publish,revert,unpublish,blocked}-*.png` renders were
inspected against Figma publication `50:1381`, replacement `12:224`, revert
`14:714` and unpublish `11:189`. Native headless pointer input remains intermittent;
confirmation tests dispatched DOM clicks through real forms. Mobile uses the
existing wrapping navigation until the navigation feature. The unpublish design's
archive alternative awaits the archive lifecycle feature; typography still uses
the system fallback. Dynamic blocker/empty-section content changes page height.

Menu editing: immutable Menu/MenuSection recordables, bucket-owned draft forms,
optional images, ordered sections and per-section product placements, removal
without deleting history, duplicate guards, and notices naming other sections.
Move-up/down controls prepare ordering changes; Save order persists them with
stale-save protection and events. Empty drafts are allowed. Preview combines
draft menu/section presentation with published product versions, flags missing
publications, filters archived items/empty visible sections, and shows live
availability without changing it. Editors/admins alone can access management,
preview, or generic recording diffs. Migration `20261016000400` is applied.

Menu verification: full suite passed 675 tests / 2,736 assertions before the last
three focused coverage additions; those additions passed in a 7-test / 101-assertion
run. Full RuboCop clean (363 files), Archspec passed (186 files, reported analysis
gaps remain). Temporary Chrome test `tmp/menu_visual_test.rb` passed 32 assertions
covering menu/section saves with uploads, shared placements, Stimulus reordering,
loaded image slots and no overflow at 1440px/390px. Six full-page screenshots
(`tmp/catalogue-menu-*`, `tmp/catalogue-section-*`, `tmp/catalogue-menu-preview-*`)
were inspected against Figma `5:2`, `5:38`, `48:582`, `48:639`.
Images use uploaded content; Figma's labelled sample artwork is a data slot,
not application decoration. The browser fixture uses an existing test image.
Native headless input remains intermittent; affected inputs/buttons used DOM
events, with real form handlers and HTTP responses. Product selection is included
in the section form rather than a separate picker screen. Ordering is in expandable
panels, with the design's up/down controls. Menu publication/status/revert controls
and menu archive lifecycle remain in their separately tracked features.

Product publication: immutable snapshots and release state have model coverage.
The editor links to impact review with before/after prices and allergen wording,
live-menu impact, and publish/unpublish controls. Revert has its own confirmation,
preserves history, availability and publication status, and identifies archived
references before and after the operation. Server policies guard all endpoints;
confirmations reject missing/stale tokens. Failed publication rolls back its
snapshot, and live-menu references block unpublishing (model contract tested;
end-to-end menu integration will be tested with menu publication).
Full regression: 654 tests, 2,503 assertions; full RuboCop clean (333 files).
Archspec passed (168 files, reported analysis gaps remain).
Figma publication `11:2` and revert `14:684` were inspected with code context and
screenshots; rendered desktop/mobile pages were visually compared. A temporary
browser test (`tmp/publication_visual_test.rb`) passed 21 assertions, covering
publish/revert/unpublish and no overflow at 1440px/390px. Chrome native input
events were intermittently absent, so publication buttons used DOM click events
through their real rendered form handlers; native pointer interaction remains
a verification limitation. Screenshots are local ignored `tmp/catalogue-*.png`.
The dynamic price/allergen review is taller than the sample, and shows explicit
before/after wording. Navigation still lacks Menus and Back to Overview pending
those tracked features. Migration `20261016000300` is applied.

Model coverage correction: the initial features relied too heavily on controller
workflow tests. Added direct tests for category, allergen, product, variant,
availability, draft editing, ordering/bulk assignments, and recording lifecycle.
These cover immutable history, validation, bucket/parent ownership, stale writes,
retired references, attachments, and transaction rollback with successful retry.
The tests exposed and fixed cross-bucket product edits, cross-product variant
edits, initial variant validation, and variant retry state after rollback.
Publication model tests also cover the backend currently in progress; publication
remains incomplete until its UI and controller flows are implemented.
Verification: 301 model tests / 928 assertions; full suite 641 tests / 2,366
assertions; RuboCop clean (327 files); Archspec passed (166 files, with reported
analysis gaps). All migration files in this checkout are applied.

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
