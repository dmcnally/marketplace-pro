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

## Archiving behavior and rationale

Archiving means an item has been withdrawn from sale. It must stop being
orderable immediately rather than waiting for the next menu publication.
Temporary unavailability serves a different purpose: use the availability toggle
for "sold out today" and archive for "we no longer offer this."

- Archiving a variant makes it unavailable across all menus in the bucket,
  including the live menu.
- Archiving a product makes all its variants unavailable across all menus in the
  bucket, including the live menu.
- Archived products and variants are excluded from future menu selection.
- Archived categories and allergens cannot be newly assigned to products or
  variants. Existing assignments and event history remain intact. Archiving a
  classifier or allergen retires it from future use without silently removing
  information from existing products, variants, or published snapshots.
- Archived categories and allergens can be restored, making them available for
  assignment again. Restoration preserves existing assignments and is tracked
  through events.
- Published content snapshots and event history are preserved. Live availability
  prevents ordering withdrawn items without rewriting what was published.
- Products and variants can be restored, but restoration does not automatically
  make them available. An editor or admin must explicitly enable availability.
  This prevents an administrative restoration from unintentionally resuming sales.
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
- Variants have a required name and price, availability, and allergen assignments.
  They use the product's description and image; variant-specific descriptions and
  images are not required.
- Every product has at least one variant. A product without choices uses a single
  default variant.
- Availability is controlled per variant and applies across all menus in the
  bucket. One variant can be unavailable while another remains available.
- Adding a product to a menu section includes all its variants. There is no
  per-menu variant selection.

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
- Ordering changes are tracked through events and require republishing to change
  the published snapshot.
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

## Menu publication

- Editors and admins can open a basic draft menu preview page before publishing.
  It uses simple styling and shows the draft's sections, products, variants,
  prices, images, and allergens together. Previewing does not publish the menu
  or change the live snapshot. A full customer-facing design is outside the
  current scope.
- A bucket may have at most one published menu at a time.
- Publishing requires at least one section containing a product. Empty menus
  and empty sections may be saved as drafts.
- Publication omits empty sections from the published snapshot while retaining
  them in the draft, so unfinished sections do not produce empty headings.
- Publishing a menu automatically replaces the bucket's currently published menu.
- Replacement must be atomic, including under concurrent publish requests.
- Published menus snapshot content and prices. Changes to products, prices, and
  sections require republishing before they appear on the published menu.
- Menu and section images are included in the published snapshot. Changing
  those images requires republishing.
- Variant availability remains live, so availability changes take effect without
  republishing.
- Allergen changes also require republishing; they do not change the live
  snapshot automatically.
- Editors and admins can unpublish without a replacement, leaving no published
  menu. A future customer-facing message such as "We're updating the menu" is
  outside the current requirements.

## Permissions

- Bucket editors and admins can manage Products, Categories, Allergens, and Menus.
- Editors and admins can publish menus, replace the live menu, and unpublish
  without replacement.
- Other users do not gain management access merely by being bucket members.

## Navigation

- The main area sidebar has Overview and Orders, in that order.
- Orders links to an Orders page.
- Editors and admins also see an Admin link in the main sidebar.
- The admin sidebar has Products, Categories, Allergens, and Menus, in that order.
- Admin includes a Back to Overview link to return to the main area.
- Articles is not a sidebar item.

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

## Deferred work

- Order processing behavior and permissions, including the division of
  responsibilities between Rails and Android, will be defined separately.

## Implementation status

The latest decisions above are documented only. The existing Figma showcase has
Products, Categories, Allergens, and Menus in its sidebar, but still needs the
main/admin navigation split and the corresponding Marketplace screens. Rails
also needs the domain features and navigation implemented.
