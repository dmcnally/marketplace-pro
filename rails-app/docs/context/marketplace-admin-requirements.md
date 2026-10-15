# Marketplace admin requirements

These are the confirmed product decisions for the Marketplace admin. They are
requirements, not a statement that the features are implemented. They supersede
earlier editorial navigation and any conflicting Marketplace design assumptions.

## Ownership

- A bucket is the owner boundary for content and membership access.
- Do not model a bucket as containing multiple sites.
- Each bucket manages its own allergen list.
- Each bucket uses one currency for all prices.

## Invariants for history and archiving

- All domain changes must be tracked through events. This includes every product,
  variant, and allergen change, as well as category and menu changes.
- Track creation, content and price edits, relationship and allergen assignment
  changes, availability changes, archiving, restoration, and publication transitions. Bulk UI
  operations must preserve the history of the affected records.
- Products, variants, categories, allergens, and menus are archived, never deleted. Preserve their
  history and references from published snapshots.
- Products, variants, and menu content use the existing immutable recordable
  pattern: edits create new versions. Availability is separate operational state
  and remains live, but its changes must also produce events.

## Event history views

- Products, menus, categories, and allergens each have a history view showing
  who changed what and when.
- A product's history includes its variant changes, so editors can follow the
  product and its variants together without switching between separate histories.
- History covers content, prices, assignments, ordering, availability,
  publication, unpublication, archiving, restoration, and reverting as applicable
  to the resource. Bulk operations must retain the affected record-level changes.
- Content-change events offer a before-and-after comparison, including names,
  descriptions, prices, and allergen assignments. Reuse the existing diff
  functionality where applicable and include relationship changes in the
  comparison rather than limiting it to scalar recordable fields.
- History and its comparisons are read-only in the current scope. Restoring an
  arbitrary historical content version is deferred. Revert all to the most
  recently published version is the only content rollback action initially;
  archive restoration remains a separate supported operation.

## Archiving behavior and rationale

Archiving means an item has been withdrawn from sale. It must stop being
orderable immediately rather than waiting for the next menu publication.
Temporary unavailability serves a different purpose: use the availability toggle
for "sold out today" and archive for "we no longer offer this."

- Archiving a variant makes it unavailable across all menus in the bucket,
  and immediately omits it from the live menu without republishing.
- Archiving a product makes all its variants unavailable across all menus in the
  bucket and immediately omits the product and its variants from the live menu
  without republishing. Archived items are not displayed as sold out.
- Archived products and variants are excluded from future menu selection.
- Archived categories and allergens cannot be newly assigned to products or
  variants. Existing assignments and event history remain intact. Archiving a
  classifier or allergen retires it from future use without silently removing
  information from existing products, variants, or published snapshots.
- Archived categories and allergens can be restored, making them available for
  assignment again. Restoration preserves existing assignments and is tracked
  through events.
- Published content snapshots and event history are preserved. The live menu
  filters out archived products and variants without rewriting historical
  published versions. They also do not appear in Overview's live-menu
  availability controls.
- After filtering archived items, the live menu hides products with no visible
  variants and sections with no visible products. This takes effect without
  republishing and does not delete their draft structure or published history.
  Temporary unavailability alone does not make a variant invisible.
- Products and variants can be restored, but restoration does not automatically
  make them available. A bucket member must explicitly enable availability once
  the item is on the currently published menu.
  This prevents an administrative restoration from unintentionally resuming sales.
- Restored products and variants automatically reappear without republishing
  when they remain included in the live menu's published structure and published
  product version, provided their parent product is not archived. Previously
  hidden products and sections reappear when they contain visible content again.
  The restored variants remain unavailable until a bucket member explicitly
  enables them. This preserves menu structure without automatically resuming sales.
- Archiving the currently published menu atomically unpublishes it. An archived
  menu must not remain live; the bucket may then have no published menu.
- Archived menus can be restored as unpublished drafts. Restoration never
  publishes a menu or replaces the current live menu; an editor or admin must
  explicitly publish it. This prevents restoration from unintentionally changing
  what customers can order.
- Archiving, its availability effects, restoration, and unpublishing must all be
  tracked through events so the withdrawal and any later return can be explained.

## Products and variants

- Products are food and drink only.
- Products have a required name, optional description, and optional image.
- Products have variants, each with its own price.
- Variant prices may be zero for complimentary items. Negative prices are
  rejected.
- Variants have a required name and price, availability, and allergen assignments.
  They use the product's description and image; variant-specific descriptions and
  images are not required.
- Every product has at least one variant. A product without choices uses a single
  default variant.
- Availability is controlled per variant and applies across all menus in the
  bucket. One variant can be unavailable while another remains available.
- New variants, including the first default variant and variants copied from
  another, start unavailable. A bucket member must explicitly enable them once
  they appear on the currently published menu;
  copying a variant does not copy its availability. This prevents accidental
  introduction of a new variant for sale.
- Adding a product to a menu section includes all its variants. There is no
  per-menu variant selection. The live menu uses the variants in the product's
  published version, excluding archived variants; draft variants are not exposed.

## Categories and menu sections

- Menus and menu sections each have a required name, optional description, and
  one optional image. A menu image can serve as a cover or banner; a section
  image can introduce that section.
- Categories classify products. A product can belong to multiple categories.
- Categories have a required name and optional description, with no image in
  the current scope.
- Categories do not define menu sections.
- Each menu has its own ordered sections, containing selected products in a
  chosen order. Different menus can group the same products differently.
- Editors and admins can manually reorder menu sections, products within each
  section, and variants within each product. Product order is specific to its
  section; variant order belongs to the product.
- Ordering changes are tracked through events. Section and product placement
  ordering requires menu republication; variant ordering requires product
  republication.
- A product may appear in multiple sections of the same menu. These placements
  share the same variants, prices, and availability; they are not separate
  product copies.
- The menu editor must visibly indicate when a product appears in multiple
  sections and identify the other sections containing it. This is informational
  and must not block the placement.
- A product can appear only once within a given menu section. Duplicate
  placement within the same section must be blocked.

## Allergens

- Allergens have a required name and optional description, with no image in
  the current scope.
- Allergen assignments belong to variants.
- Product-level allergen assignment is a bulk editing UI concern, not a separate
  persisted assignment or inheritance mechanism.
- The product editor can assign or remove an allergen across all variants.
- Each variant's assignments can then be adjusted independently.
- New variants copy allergens from an existing variant rather than starting
  with no assignments. The copied assignments remain editable.
- An Add variant from control selects the source variant, with the default
  variant preselected. The first variant starts with no allergens assigned and
  must be reviewed.
- The allergen list is owned and managed by the bucket, not shared globally
  across the application.
- Changes to an allergen's name or description retain the previously published
  wording on published products until each affected product is republished.
  Flag the affected products as having unpublished changes.
- Show a prominent warning that allergens have been edited and the live menu may
  be inaccurate when affected products appear on the live menu. Identify the
  affected products and direct editors/admins to review and republish them.
- This warning appears in admin for editors and admins, not on the staff
  Overview page.
- The same warning covers unpublished additions or removals of allergen
  assignments on variants of products appearing on the live menu, including
  assignments changed through the product-level bulk editor. Flag the affected
  products for review and republication; live assignments remain those in the
  published product version until it is republished.
- The warning remains while the live menu references products whose published
  allergen information differs from the edited information. Republishing the
  menu alone does not resolve it; the affected products must be republished
  or cease to appear on the live menu.

## Separate publication lifecycles

- A product and all its variants publish together as one consistent version,
  independently of menu publication. This version includes product content,
  images, variant prices, variant ordering, and allergen information.
- Draft product and variant edits remain invisible until the product is published.
- Publishing a product requires at least one non-archived variant with a valid
  name and price. Temporary unavailability does not block publication: editors
  can publish content updates even when the product is sold out.
- Products have a separate Unpublish action, distinct from availability and
  archiving. It applies to the product and its variants together and must be
  tracked through events.
- Block product unpublishing while the product is referenced by the live menu.
  The editor must remove it from every section containing it and republish the
  menu before unpublishing the product. Removing it only from the draft is not
  enough. Unpublishing the menu also removes the live reference.
- This initial restriction preserves the rule that every live menu product has
  a published version. Availability can stop sales immediately without changing
  publication. Revisit the restriction if it causes excessive workflow friction.
- A menu publishes its own presentation and structure: name, description, image,
  ordered sections, section presentation, and product placements.
- The live menu combines its published structure with each referenced product's
  published version. Publishing a product update updates it on the live menu
  without requiring menu republication.
- Availability remains separate and live, regardless of either publication cycle.
- Publishing requires confirmation summarizing its impact. For menu publication,
  identify the currently published menu being replaced, if any. For product
  publication, explain whether the changes will appear on the live menu and
  highlight price and allergen changes. The confirmation must reflect the
  resource's publication scope.
- This separation keeps menu arrangement independent of catalogue editing and
  gives reverting a clear scope without rolling back shared products from a menu.

## Unpublished changes and reverting

- Menu and product editors show an Unpublished changes indicator for changes
  within their own publication scope. Product edits do not make the menu
  structure dirty.
- Editors and admins can revert all unpublished changes within that scope to
  its most recently published version, even if it is currently unpublished.
  Revert is unavailable for products and menus that have never been published.
  Menu revert restores only its presentation, sections,
  and placements. Product revert restores its content and variants, including
  prices and allergens.
- Reverting preserves history and is tracked through events. It does not alter
  live availability or revert another resource's content. Reverting a draft
  does not publish it or change its publication status.
- Revert all requires confirmation explaining that it replaces the current
  draft with the most recently published version, preserves event history,
  and leaves live availability unchanged. This prevents accidental loss of
  current draft work.
- Revert preserves archive status. If the restored draft references variants
  or other records that have since been archived, they remain archived; archived
  variants remain unavailable. Show a notice identifying the archived references
  and explaining that restoration is a separate action. Reverting content must
  not silently undo a withdrawal from sale.

## Menu publication

- Editors and admins can open a basic draft menu preview page before publishing.
  It uses simple styling and combines the draft menu presentation and sections
  with each product's published version, including its variants, prices, images,
  and allergens. Product draft edits are not shown. Products without a published
  version are clearly flagged as publication blockers. This reflects what menu
  publication would display without hiding unresolved products. Previewing does
  not publish the menu or change the live snapshot. A full customer-facing
  design is outside the current scope.
- A bucket may have at most one published menu at a time.
- Publishing requires at least one section containing a product. Empty menus
  and empty sections may be saved as drafts.
- Draft menus may include products that have no published version. Menu
  publication is blocked until every included product has a published version.
  Identify each blocking product and prompt the editor to publish it or remove
  it from the menu. Do not silently omit it or publish it automatically.
- A product with a published version and newer unpublished edits does not block
  menu publication; the live menu uses its published version.
- Publication omits empty sections from the published snapshot while retaining
  them in the draft, so unfinished sections do not produce empty headings.
- Publishing a menu automatically replaces the bucket's currently published menu.
- Replacement must be atomic, including under concurrent publish requests.
- Published menus snapshot menu presentation, section content, ordering, and
  product placements. Product content and prices follow their separate published
  product version rather than being frozen into the menu snapshot.
- Menu and section images are included in the published snapshot. Changing
  those images requires republishing.
- Variant availability remains live, so availability changes take effect without
  republishing.
- Allergen changes require publishing the affected product and its variants;
  menu republication is not required. Draft allergen edits do not appear live.
- Editors and admins can unpublish without a replacement, leaving no published
  menu. A future customer-facing message such as "We're updating the menu" is
  outside the current requirements.

## Permissions

- Every bucket member can toggle variant availability within their bucket, only
  for products and variants on the currently published menu. Draft menu placement
  or product publication alone does not make an item eligible for availability
  controls. No availability controls apply to items outside the published menu.
  Availability changes are tracked through events. This permission does not
  grant access to content editing, publication, archiving, or restoration.
- Bucket editors and admins can manage Products, Categories, Allergens, and Menus.
- Editors and admins can publish menus, replace the live menu, and unpublish
  without replacement.
- Editors and admins can publish products together with their variants.
- Editors and admins can unpublish products together with their variants.
- Other users do not gain management access merely by being bucket members.

## Navigation

- The main area sidebar has Overview and Orders, in that order.
- Orders links to an Orders page.
- Editors and admins also see an Admin link in the main sidebar.
- The admin sidebar has Products, Categories, Allergens, and Menus, in that order.
- Admin includes a Back to Overview link to return to the main area.
- Articles is not a sidebar item.

## Overview

- Overview shows the live menu's products and variants with availability controls
  accessible to every bucket member.
- A product-level availability toggle is a bulk UX control for all of that
  product's published variants. Availability is stored only per variant; there
  is no separate product availability state. Each affected variant's change is
  tracked through events.
- Availability controls are scoped to those published-menu products and variants;
  unpublished draft variants are not included. When there is no published menu,
  there are no eligible availability controls.
- Staff can mark variants available or sold out without admin access or an
  additional sidebar page. These controls change only live availability;
  content editing and publication remain restricted to editors and admins.

## Orders

- Orders is a staff view of all orders in the current bucket.
- Every bucket member can view those orders, regardless of membership role.
- Viewing orders does not grant permission to change them; order actions and
  their permissions remain to be decided.
- Order processing actions, such as accepting, completing, or cancelling orders,
  are outside the current admin build and will be developed later. Part of that
  workflow will be handled by the Android application; the division of
  responsibilities between Rails and Android remains to be defined.
- The customer side of the application has not yet been scoped and is outside
  the current requirements.

## Editing concurrency and scope

The initial application serves a small takeaway, likely with one person managing
the catalogue and menus. Concurrent editing is possible but uncommon; keep the
workflow simple.

- Provide basic stale-save protection so one editor does not silently overwrite
  another editor's changes. On a conflict, ask the editor to reload.
- Reject a stale publication confirmation if the draft changed after review;
  require reviewing the current draft before confirming publication again.
- Collaborative editing, automatic merging, and advanced concurrency workflows
  are outside the initial scope. Atomic menu replacement remains required.
- The core admin decisions are sufficiently defined to proceed to implementation
  planning without expanding the initial feature scope.

## Deferred work

- Collaborative editing, automatic merging, and advanced concurrency workflows.
- Restoration of arbitrary historical content versions.
- Order processing behavior and permissions, including the division of
  responsibilities between Rails and Android, will be defined separately.

## Implementation status

The latest decisions above are documented only. The existing Figma showcase has
Products, Categories, Allergens, and Menus in its sidebar, but still needs the
main/admin navigation split and the corresponding Marketplace screens. Rails
also needs the domain features and navigation implemented.
