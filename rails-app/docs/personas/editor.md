# Editor persona

## Alex — menu editor

Alex is the person responsible for keeping a small takeaway's food and drink
menu accurate, appealing, and ready for service. They combine catalogue upkeep
with menu curation, often alongside other day-to-day responsibilities. Alex is
comfortable with forms and previews but should not need technical knowledge to
understand what customers will see.

> “I want to turn our agreed food and drink offering into a clear menu, check
> every price and allergen, and know exactly when my changes go live.”

This is a representative persona, not a new user account. Its workflow follows
the [Marketplace admin requirements](../context/marketplace-admin-requirements.md).

## Responsibilities and working style

- Own the quality of product names, descriptions, images, variants, prices,
  categories, and allergen information within their business's workspace.
- Build and curate menus: choose products, group them into sections, and order
  sections, products, and variants so customers can find and compare choices.
- Review drafts, publish products and menus, and maintain the live offering.
- Coordinate with the owner or kitchen to verify the offering, prices,
  ingredients, and readiness for sale. Never guess missing allergen information
  or assume an empty allergen list means an item is allergen-free.
- Use concise, consistent wording and relevant images; avoid duplicate products
  when the same item belongs in more than one menu section.
- Use history to understand changes and archive retired content to preserve it.

Alex has the editor role, which can manage Products, Categories, Allergens, and
Menus and publish them where applicable. Membership administration and order
processing are outside this persona's responsibilities. Day-to-day availability
can also be managed by other workspace members.

## Goals, frustrations, and success

Alex wants a menu that is easy to browse, accurately describes every choice,
and contains only the intended offering. Their main frustrations are re-entering
the same information, unclear draft/live states, stale prices or allergens, and
accidentally making an item available before the kitchen is ready.

Success means all intended products are in the correct sections and order,
published prices and allergens match the agreed source information, the intended
menu is live, and availability matches what staff can actually serve.

## Tasks to populate the first menu

### 1. Gather the source information

Agree the menu's purpose and offering with the owner or kitchen. Collect product
names, descriptions, images where useful, variant names, prices in the workspace
currency, and verified allergens for each variant. Identify missing information
and resolve it before publishing the affected products.

**Result:** a checked list of food and drink items and their choices, plus a
proposed section order.

### 2. Prepare categories and allergens

Use Categories and Allergens in the main sidebar to review existing entries before adding new
ones. Reuse suitable entries and write clear names and descriptions. Categories
classify products; they do not create the menu's sections. A product can have
multiple categories.

**Result:** a consistent set of classifications and allergen entries to assign.

### 3. Create products and variants

In Products, create each product with its required name and optional description
and image. Assign relevant categories. Give every product at least one variant;
use a single default variant when there are no choices. Enter each variant's
name and price, assign its verified allergens, and arrange variants in a useful
order. Zero prices are allowed for complimentary items; negative prices are not.

Use the product-level allergen controls for shared assignments, then review each
variant independently. When adding a variant from another variant, check the
copied allergens against the actual recipe. The first variant starts with no
allergen assignments, so it also needs an explicit review.

New variants start unavailable. Leave availability for the service-readiness
check after the menu is live.

**Result:** complete product drafts with checked choices, prices, and allergens.

### 4. Review and publish the products

Check spelling, descriptions, images, variant order, prices, and allergen
assignments against the agreed source information. Review the publication
confirmation and publish each ready product. A product and its variants publish
together. At least one non-archived variant with a valid name and price is
required; temporary unavailability does not prevent publication.

Publishing an update to a product already on the live menu changes its live
content immediately, including prices and allergens. Treat that confirmation
as the release point for the product.

**Result:** published products ready to appear in a menu.

### 5. Assemble and curate the menu

In Menus, create a named draft and optionally add a description and cover image.
Create named sections, adding descriptions or images where useful. Select the
products for each section and arrange the sections and products in the order
customers should encounter them.

For example, a menu might contain Mains, Sides, and Drinks. A product may appear
in several sections, but only once in any individual section. Reuse the same
product for those placements. Adding a product includes all variants from its
published version; the editor cannot choose different variants for each menu.

**Result:** an ordered draft menu with deliberate product placements.

### 6. Preview and resolve gaps

Open the draft menu preview and read it as a customer would. Check section
grouping, product order, wording, imagery, prices, and allergens. The preview
combines draft menu structure with published product content, so unpublished
product edits will not appear. Publish those product edits separately if they
are intended for this release.

Resolve every unpublished-product blocker by publishing the product or removing
it from the menu. There must be at least one section containing a product.
Empty draft sections are omitted when publishing.

**Result:** a reviewed menu with no publication blockers.

### 7. Publish the menu

Review the publication confirmation, including which current menu will be
replaced. Publish when the arrangement is ready. Only one menu can be live in
the workspace at a time; publishing this menu replaces the previous live menu.

**Result:** the intended menu presentation, sections, and placements are live.

### 8. Enable items for service

Return to Overview and check the live menu with staff. Explicitly enable the
variants that are ready to sell, leaving others unavailable. Confirm the
expected products and choices appear and availability matches the kitchen.

**Result:** a populated live menu with availability deliberately set for service.

## Ongoing curation

- **Before service:** check the live menu and coordinate availability with staff.
  Use availability for temporary sold-out items; it takes effect immediately
  without publishing.
- **When content changes:** update product descriptions, images, variants, prices,
  or allergens and republish the affected products. Menu republication is not
  needed for those product updates. Review allergen-change warnings promptly;
  republishing only the menu does not resolve them.
- **When the arrangement changes:** edit menu or section presentation, placements,
  or ordering, preview, and republish the menu. Product variant ordering belongs
  to the product and requires product republication instead.
- **When an item is retired:** archive the product or variant. It disappears from
  the live menu immediately. Restoring it does not automatically make it
  available again. Archiving the live menu unpublishes that menu; restoring it
  returns it as an unpublished draft.
- **When unpublishing a product:** first remove it from every section of the live
  menu and republish that menu, or unpublish the menu. Removing draft placements
  alone does not release the live references.
- **When reviewing or correcting work:** consult history for who changed what
  and when. Revert all can restore a product or menu draft to its most recently
  published version; it preserves history and does not change availability or
  publication status. Review its confirmation before discarding draft work.

## Completion checklist

- Every intended product has checked variants, prices, and allergen assignments.
- All included products have the intended published version.
- Menu sections and placements are complete and ordered deliberately.
- Preview has been reviewed and publication blockers are resolved.
- The intended menu is live and any replacement was deliberate.
- Staff have confirmed which live variants should be available.
