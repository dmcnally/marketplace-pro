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
  changes, availability changes, archiving, and publication transitions. Bulk UI
  operations must preserve the history of the affected records.
- Products, variants, and menus are archived, never deleted. Preserve their
  history and references from published snapshots.
- Products, variants, and menu content use the existing immutable recordable
  pattern: edits create new versions. Availability is separate operational state
  and remains live, but its changes must also produce events.

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

- Categories classify products. A product can belong to multiple categories.
- Categories do not define menu sections.
- Each menu has its own ordered sections, containing selected products in a
  chosen order. Different menus can group the same products differently.

## Allergens

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

- A bucket may have at most one published menu at a time.
- Publishing a menu automatically replaces the bucket's currently published menu.
- Replacement must be atomic, including under concurrent publish requests.
- Published menus snapshot content and prices. Changes to products, prices, and
  sections require republishing before they appear on the published menu.
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

## Decisions still to make

- Orders page behavior and whose orders each role can access.
- Whether archiving a product or variant immediately marks affected live variants
  unavailable, and how archived items are excluded from future menu selection.
- Whether archiving the currently published menu automatically unpublishes it or
  requires unpublishing first.
- Whether archived records can be restored.

## Implementation status

The latest decisions above are documented only. The existing Figma showcase has
Products, Categories, Allergens, and Menus in its sidebar, but still needs the
main/admin navigation split and the corresponding Marketplace screens. Rails
also needs the domain features and navigation implemented.
