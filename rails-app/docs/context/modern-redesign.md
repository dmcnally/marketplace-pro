# Modern redesign: scope and handoff

## Current document invariants

The confirmed domain and navigation requirements are maintained in
[Marketplace admin requirements](marketplace-admin-requirements.md). They take
precedence over the historical editorial redesign scope below.

- A bucket is the owner boundary for content and membership access. Do not model a bucket as containing multiple sites.
- Each bucket may have at most one published menu at a time.
- Publishing atomically replaces the current menu. Published content, prices, and allergens are snapshots; availability remains live. Editors and admins may unpublish without replacement.
- Products, variants, and menus are archived, never deleted. Products, variants, and menu content use immutable recordables.
- All domain changes must be tracked through events, including every product, variant, and allergen change, relationship changes, availability, archiving, and publication transitions.
- Each bucket uses one currency. Products have a required name, optional description, and optional image; variants have a required name and price, availability, and allergens.
- The admin sidebar contains Products, Categories, Allergens, and Menus, in that order.
- The main sidebar contains Overview and Orders, in that order. Editors and admins also see an Admin link. Orders links to an Orders page.
- The admin area includes a Back to Overview link. Editors and admins can manage all four admin sections and publish menus.
- Articles is not a sidebar item.
- These requirements supersede the earlier editorial navigation described below. The admin/non-admin navigation split is documented only; Figma and Rails still require updates to reflect it. Menu functionality also remains to be implemented.

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

[Blogger · Modern redesign](https://www.figma.com/design/H6dpgQ8jzdr0zH2MlT9iUM/Blogger-Modern-redesign)

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
