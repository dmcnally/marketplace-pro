# Modern redesign: scope and handoff

For the completed Marketplace catalogue/admin implementation and latest runtime
evidence, see [Final admin verification](admin-verification.md). Historical
editorial redesign notes below are retained for continuity; the confirmed
Marketplace requirements and that verification report describe the current scope.

## Current document invariants

The confirmed domain and navigation requirements are maintained in
[Marketplace admin requirements](marketplace-admin-requirements.md). They take
precedence over the historical editorial redesign scope below.

- A bucket is the owner boundary for content and membership access. Do not model a bucket as containing multiple sites.
- Each bucket may have at most one published menu at a time.
- Publishing requires at least one section containing a product; empty menus and sections can be saved as drafts.
- Draft menus may include unpublished products, but publishing is blocked for products without a published version. The editor must publish or remove each blocking product; no silent omission or automatic product publication. New draft edits to an already published product do not block the menu.
- Empty sections are omitted from the published snapshot and retained in the draft.
- Editors and admins can manually reorder sections, products within sections, and variants within products. Ordering changes are tracked through events and require republishing.
- Menu publication atomically replaces the current menu and publishes its presentation, sections, and product placements. Products and their variants publish together on a separate lifecycle, including prices and allergens. The live menu uses each product's published version; product updates do not require menu republication. Availability stays live. Editors and admins may unpublish menus without replacement.
- Products, variants, categories, allergens, and menus are archived, never deleted. Products, variants, and menu content use immutable recordables.
- Archived categories and allergens retain existing assignments and history but cannot be newly assigned to products or variants.
- Categories and allergens can be restored to make them assignable again; restoration is tracked through events.
- A product may appear in multiple sections of a menu, sharing variants, prices, and availability. The editor must visibly indicate these placements and identify the other sections; the indicator does not block placement.
- A product may appear only once within each menu section; duplicate placement in the same section is blocked.
- Menus and sections each have a required name, optional description, and one optional image. Their images are part of the published snapshot and require republishing when changed.
- Editors and admins have a basic menu preview page with simple styling, combining draft menu structure with published product versions. Products without a published version are clearly flagged as blockers. Previewing does not publish or change the live menu; a full customer-facing design remains outside scope.
- Menu and product editors indicate unpublished changes within their own publication scope and offer reverting to their published version. Menu revert affects presentation and structure; product revert affects its content and variants. Reverts preserve history, produce events, and leave live availability unchanged.
- Revert uses the most recently published version even when currently unpublished. It is unavailable before first publication and does not change publication status.
- Revert all requires confirmation explaining that the current draft is replaced, event history is preserved, and live availability remains unchanged.
- Publishing requires an impact confirmation: identify the live menu being replaced for menu publication, and explain live-menu impact with price/allergen changes highlighted for product publication.
- Target a small takeaway with likely one catalogue manager. Keep basic stale-save protection and reject publication confirmations when the reviewed draft has changed; defer collaborative editing, automatic merging, and advanced concurrency workflows. Atomic menu replacement remains required.
- Revert preserves archive status. Archived references remain archived, archived variants remain unavailable, and a notice explains that restoration requires a separate action.
- Products have a separate Unpublish action for editors and admins, applying to the product and variants together and tracked through events. Block it while the product is referenced by the live menu: remove all its placements and republish the menu first, or unpublish the menu. This initial restriction may be revisited if it causes workflow friction; availability can stop sales immediately.
- Product publication requires at least one non-archived variant with a valid name and price. Temporary unavailability does not block publication.
- Allergen name/description edits mark affected products as having unpublished changes while published wording remains unchanged until product republication. If affected products appear on the live menu, prominently warn that allergen edits may make it inaccurate and identify those products. Menu republication alone does not resolve the warning.
- The allergen-change warning is shown in catalogue management to editors and admins, not on the staff Overview page.
- The same warning covers unpublished variant allergen assignment changes, including bulk edits, for products appearing on the live menu. Published assignments remain unchanged until product republication.
- Archiving immediately omits products and variants from the live menu and Overview availability controls without republishing, and excludes them from future selection. Published history is preserved; archived items are filtered from live display rather than shown as sold out. Restoring products or variants does not automatically enable availability. Archiving the published menu atomically unpublishes it.
- Restored menus return as unpublished drafts and require explicit publication; restoration never replaces the live menu.
- After archived items are filtered out, hide live-menu products with no visible variants and sections with no visible products, without republishing or deleting history. Temporary unavailability alone does not hide variants.
- Restored items reappear automatically if still included in the published menu and product version and their parent product is not archived; newly populated containers reappear too. Restored variants remain unavailable until a bucket member explicitly enables them.
- All domain changes must be tracked through events, including every product, variant, and allergen change, relationship changes, availability, archiving, and publication transitions.
- Products, menus, categories, and allergens each have a history view showing who changed what and when. Product history includes variant changes, including changes made through bulk controls.
- Content-change history offers before-and-after comparisons for names, descriptions, prices, and allergen assignments, reusing existing diff functionality where applicable.
- History is read-only. Arbitrary historical content restoration is deferred; Revert all to the most recently published version is the only initial content rollback action, separate from archive restoration.
- Each bucket uses one currency. Products have a required name, optional description, and optional image; variants have a required name and price, availability, and allergens.
- The main sidebar contains Overview and Orders, followed by Products, Categories, Allergens, and Menus for editors and admins.
- Only admins see Admin. Its dashboard and sidebar are reserved for user management: Members, roles/permissions, and Invitations, with a Back to Overview link.
- Catalogue management is part of the normal workspace. Editors and admins can manage it and publish menus. Orders links to an Orders page.
- Articles is not a sidebar item.
- Orders is a staff view of all orders in the current bucket, accessible to every bucket member. Customer-facing behavior is outside the current scope; order mutation permissions remain undecided.
- Every bucket member can toggle availability only for products and variants on the currently published menu in their bucket, with changes tracked through events. Draft placement or product publication alone does not qualify. Content editing and publishing remain restricted to editors and admins.
- Overview displays the live menu's products and variants with availability controls for every bucket member, without requiring admin access or another sidebar page.
- Product-level availability toggles are bulk UX controls over published variants, not separate product state. Each affected variant change is tracked through events.
- Order processing is deferred beyond the current admin build. Part of that workflow will be handled by the Android application; the Rails/Android split will be defined later.
- These requirements supersede the earlier editorial navigation described below. The Marketplace Figma screens now represent the main/admin navigation split and confirmed workflows; see [Figma requirements coverage](marketplace-figma-coverage.md). Rails catalogue workflows are implemented; see [verification](admin-verification.md). The current [workspace navigation](workspace-navigation.md) supersedes older sidebar descriptions below.

## What was missed

The user requested the Modern Figma design across Blogger. The first pass
incorrectly implemented only `/admin` and `/admin/dashboard`, leaving the
homepage, articles, authentication, management pages, and shared components
unchanged. The user explicitly rejected this narrow scope. A matching admin
overview alone does not complete this task.

The user explicitly chose **existing functionality**. Keep real bucket-scoped
data and existing authorization/actions. Do not invent digest delivery, task
management, preferences persistence, analytics, or last-active timestamps.
Label unsupported features clearly. Memberships provide joined dates.

## Required design sources

[Marketplace · Modern redesign](https://www.figma.com/design/UfIFxpLKXKsP9HBj9k3rfP/marketplace?m=auto&t=NVsE2yJTM0Sbdyi6-6)

- `1:2`: **Modern · 00 Admin showcase**, overview frame `4:2`.
- `0:1`: **Modern · 01 Foundations**, initially missed. Its shared components
  are buttons and hover states (`2:15`–`2:23`), error/notice/empty states
  (`2:25`–`2:29`), inputs (`2:31`), article cards (`2:35`), article/comment body
  fields (`2:39`, `2:43`), and publish/unpublish buttons (`2:47`, `2:49`).

Read the Figma design-to-code skill and use high-fidelity design context.
Translate into Rails ERB, existing actions, Stimulus, and BEM component CSS.
The inspected designs contain no static image or SVG assets.

## Coverage that must not be skipped

- Shared shell: dark navy sidebar, purple active navigation, light background,
  typography, spacing, account controls, mobile navigation.
- Homepage, article cards, detail, create/edit, comments, publication controls,
  timeline and diffs.
- Sign-in, registration, password reset, invitation acceptance, access states.
- Workspace admin overview, members, invitations, CSV imports and forms.
- System-admin overview, buckets, users, detail and edit views.
- Shared buttons, fields, badges, feedback, empty states, lists and cards.

Keep authorization outside templates, use permission-aware actions, and preserve
Turbo responses, search, sessions, and workspace switching. Never show Figma
sample names, counts, or activity as real application data.

## Current status

The first pass added `Admin::WorkspaceOverview`, `layouts/admin_workspace`,
`workspace.css`, and the search shortcut. Its 566-test run passed before the
broader correction. That earlier result does not validate subsequent edits.

The broader correction is implemented: shared tokens in `application.css`,
existing component styles, application and management shells, permission-aware
`NavigationActions`, and CSV import presentation now use the Modern foundations.
The dashboard's CSS aliases the same global color tokens. The homepage now uses
the dark sidebar and Modern article cards, rather than retaining the old theme.

Validation after the correction: **568 Rails tests, 1,746 assertions, no failures**;
changed Ruby files pass RuboCop; Archspec passes. Navigation integration tests
cover guest restrictions and admin links from the article screen. A temporary
Selenium render check exercised homepage, sign-in, article detail, article editor,
members, invitations, imports, system overview, buckets, and users at 1440px and
390px, with no horizontal page overflow (30 assertions). Representative renders
were visually inspected. Screenshots are local ignored `tmp/modern-*.png` files,
not durable project assets. Other views inherit the shared component changes;
not every individual form/error/data state received a screenshot.

Typography uses an Inter-first system font stack; no Inter font file is bundled.
Pages beyond the Figma showcase use its shared foundations and existing content,
since Figma does not supply a separate full-page mockup for every route.

## Verification and environment

Inspect the actual `/` homepage plus public, authenticated, and system-admin
screens at desktop and mobile sizes. Check overflow, active navigation,
unauthorized links, forms, and feedback. Run Rails tests, Ruby lint, and
architecture checks through `docker compose exec web ...`.

Headless Chrome can clamp its layout viewport to 500px despite a smaller window;
use Selenium/CDP device metrics for a real 390px viewport. Absolutely positioned
screen-reader table labels need positioned table headers to avoid overflow.

Edits are local, not deployed. Port 3000 was started for verification. Confirm
the actual server and route the user is viewing; do not assume another running
instance serves this worktree.
