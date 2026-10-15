# Marketplace admin requirements

These are the confirmed product decisions for the Marketplace admin. They are
requirements, not a statement that the features are implemented. They supersede
earlier editorial navigation and any conflicting Marketplace design assumptions.

## Ownership

- A bucket is the owner boundary for content and membership access.
- Do not model a bucket as containing multiple sites.
- Each bucket manages its own allergen list.

## Products and variants

- Products are food and drink only.
- Products have variants, each with its own price.
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

## Permissions

- Bucket editors and admins can manage Products, Categories, Allergens, and Menus.
- Editors and admins can publish menus and replace the live menu.
- Other users do not gain management access merely by being bucket members.

## Navigation

- The main area sidebar has Overview and Orders, in that order.
- Orders links to an Orders page.
- Editors and admins also see an Admin link in the main sidebar.
- The admin sidebar has Products, Categories, Allergens, and Menus, in that order.
- Admin includes a Back to Overview link to return to the main area.
- Articles is not a sidebar item.

## Decisions still to make

- The full product and variant field list, including required descriptions,
  images, variant labels, and pricing currency rules.
- Whether and how product and menu content use the existing immutable recordable
  architecture.
- Which existing variant supplies allergens when creating a new variant, and
  the initial allergen editing flow for a product's first variant.
- Whether allergen corrections have any special publication behavior; the agreed
  general rule snapshots content and keeps only availability live.
- Orders page behavior and whose orders each role can access.
- Unpublishing without replacement, and deletion or archival of products and
  variants referenced by published snapshots.

## Implementation status

The latest decisions above are documented only. The existing Figma showcase has
Products, Categories, Allergens, and Menus in its sidebar, but still needs the
main/admin navigation split and the corresponding Marketplace screens. Rails
also needs the domain features and navigation implemented.
