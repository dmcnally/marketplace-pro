# Workspace navigation

Updated 16 October 2026. This configuration supersedes older notes that place
catalogue management inside Admin.

| Role | Main sidebar, in order | Admin access |
| --- | --- | --- |
| Staff / viewer | Overview, Orders | None |
| Editor (Alex) | Overview, Orders, Products, Categories, Allergens, Menus | None |
| Admin (Sam) | Overview, Orders, Products, Categories, Allergens, Menus, Admin | User management |

The same destinations appear in mobile navigation. Overview remains the default
landing page. Orders is a deferred destination; processing orders is not implemented.
Navigation visibility does not replace controller authorization.

Products (`/products`), Categories (`/categories`), Allergens (`/allergens`) and
Menus (`/menus`) are normal workspace functions. Their existing `admin_*` Rails
route helper names are retained internally, but their URLs have no `/admin` prefix.
Old `/admin/products`, `/admin/categories`, `/admin/allergens` and `/admin/menus`
URLs are no longer the catalogue entry points; no compatibility redirects are added.

Admin (`/admin`) contains Dashboard, Members, Invitations and Back to Overview.
Its dashboard provides team-member and pending-invitation summaries and an Invite
member action. Catalogue, Articles and Imports are not admin dashboard functions.
Sam owns invitations and permissions; editing an existing member's role remains
an implementation gap, as documented in the [admin persona](../personas/admin.md).

## Populating a menu as Alex

1. Prepare Categories and Allergens using their main-sidebar destinations.
2. Create Products, add variants and prices, and assign categories and allergens.
3. Review and publish each product with its variants.
4. Open Menus, create a draft, add sections and place the published products.
5. Arrange sections and products, then preview and resolve publication blockers.
6. Publish the menu, explicitly confirming replacement if another menu is live.
7. Use Overview to enable live variant availability and maintain it during service.

Product publication and menu publication remain separate. Menu publication uses
published product content; it does not publish product drafts or enable availability.
See [Alex's persona](../personas/editor.md) and the
[confirmed requirements](marketplace-admin-requirements.md) for the full workflow.

## Figma prototypes

- [Alex: populate a menu, desktop](https://www.figma.com/proto/UfIFxpLKXKsP9HBj9k3rfP/marketplace?page-id=69%3A1190&node-id=70-7&starting-point-node-id=70%3A7)
- [Alex: mobile](https://www.figma.com/proto/UfIFxpLKXKsP9HBj9k3rfP/marketplace?page-id=69%3A1190&node-id=70-975&starting-point-node-id=70%3A975)
- [Sam: user management, desktop](https://www.figma.com/proto/UfIFxpLKXKsP9HBj9k3rfP/marketplace?page-id=69%3A1190&node-id=86-1930&starting-point-node-id=86%3A1930)
- [Sam: mobile](https://www.figma.com/proto/UfIFxpLKXKsP9HBj9k3rfP/marketplace?page-id=69%3A1190&node-id=86-2118&starting-point-node-id=86%3A2118)

These are clickable sample-state flows, not a connected application. Sam's flow
covers the dashboard, members, invitations and sending a sample invitation; it
does not simulate editing existing permissions.
