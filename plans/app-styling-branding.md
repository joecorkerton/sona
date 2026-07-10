# Plan: App styling and Sona branding

**In-repo copy:** [`plans/app-styling-branding.md`](app-styling-branding.md) (canonical for the project;
keep in sync when revising).

## Context

The chat POC is functionally in place (see [`plans/basic-chat-poc.md`](basic-chat-poc.md) and the
related issues `008-group-dm-flows.md` / `009-layout-seeds-precommit.md`). The screenshots the user
provided show that the UI still carries the default **Phoenix 1.8 marketing chrome**: the Phoenix
logo, version string, "Website", "GitHub" and "Get Started" links, plus daisyUI's stock light/dark
themes. That chrome lives in the dead marketing page under `lib/sona_web/controllers/page_html/home.html.heex`
(the router already points `/` to `HomeLive`). The app needs to look like it belongs to **Sona**
([sona.ai](https://www.sona.ai/)): clean, warm, mobile-first, with the teal/lime/stone palette
visible on the public site.

Project constraints from [`AGENTS.md`](../AGENTS.md) matter here:

- Mobile-first design, but still usable on desktop.
- **daisyUI is allowed; retheme it to the project palette** (it's Tailwind under the hood) rather
  than writing bespoke components. We keep the `:daisyui` dep and its component classes and point
  them at Sona colors via a custom daisyUI theme.
- No external `src`/`href` references in layouts; only `app.css` and `app.js` are bundled.
- No `@apply` in raw CSS.
- Use `<.icon name="hero-..." />` for icons and `<.input>` for form fields.
- LiveView templates start with `<Layouts.app flash={@flash} current_scope={@current_scope} ...>`.
- `<.flash_group>` only belongs in `Layouts`.

This plan covers the visual reset and brand system; it does not add new chat features.

## Goals

### In scope

- Replace the stock Phoenix header with a Sona-branded app shell.
- **Keep daisyUI and retheme it to the Sona palette** so its component classes (`btn`, `alert`,
  `toast`, `navbar`, `fieldset`, `input`, `select`, `textarea`, `checkbox`, `input-error`,
  `select-error`, `textarea-error`, `table-zebra`, `list-row`, `base-content`, `text-error`,
  `btn-ghost`, `card`, `badge`, theme tokens) render in Sona colors automatically. We are *not*
  stripping daisyUI classes or dropping the dependency.
- Apply a Sona-derived color, spacing, and type system across the existing LiveViews, using
  daisyUI semantic classes (`bg-primary`, `bg-base-200`, `border-base-300`, `text-base-content`,
  `text-error`, …) plus a small set of raw `sona-*` Tailwind utilities for colors daisyUI's
  semantic tokens don't cover (e.g. lime avatars).
- Delete the dead Phoenix marketing page files (`PageController`, `PageHTML`, and
  `page_html/home.html.heex`) since `/` is already handled by `HomeLive`.
- Keep the existing user flows and page IDs intact so tests continue to pass with only
  class/selector updates if necessary.
- Ensure the experience works well at phone widths (~390px).

### Out of scope

- New chat features (groups, DMs, threads) — covered by `008-group-dm-flows.md`.
- A marketing landing page beyond the create/join forms.
- Self-hosted custom fonts (we will use a system-font stack to avoid external network requests).
- Logo asset finalisation — we will use a text wordmark/SVG placeholder; a real brand asset can be
  swapped in later without changing the layout.

## Product / user flows

No new user flows are introduced. The same flows are restyled:

1. **Create workspace (`/`)** — clean centered form with Sona wordmark, teal primary CTA.
2. **Join workspace (`/join/:token`)** — same form shape as create, Sona card styling, on-brand
   error state for invalid tokens.
3. **Inbox (`/chats`)** — company name and share-link card at the top, room list as rounded cards,
   clear "New group" / "New message" actions.
4. **Chat (`/chats/:id`)** — full-height mobile layout with a sticky composer; message bubbles use
   the Sona palette to distinguish own vs. others.

## Architecture / design

### Brand palette (derived from sona.ai CSS)

| Token | Hex / value | Usage |
|-------|-------------|-------|
| `sona-teal` | `#0d9488` | Primary buttons, links, focus rings, active states |
| `sona-teal-dark` | `#0f766e` | Hover/teal-700 states |
| `sona-lime` | `#d9f99d` | Accents, highlights, avatar fills |
| `sona-lime-dark` | `#bef264` | Lime hover state |
| `sona-blue` | `#3b82f6` | Accent badges/info (sparingly) |
| `sona-stone-50` | `#fafaf9` | Page background |
| `sona-stone-100` | `#f5f5f4` | Card backgrounds, invite URL well |
| `sona-stone-200` | `#e7e5e4` | Borders, dividers |
| `sona-stone-600` | `#57534e` | Muted text |
| `sona-stone-900` | `#1c1917` | Body text, headings |
| `sona-dark` | `#0f172a` | Dark-mode background / header option |

Font reference from the site: **Sora** (headings) and **IBM Plex Mono** (eyebrows/labels). We will
use a system-font stack (e.g. `ui-sans-serif`, `system-ui`, `Inter` if present, then sans-serif;
`ui-monospace`, `SFMono-Regular`, `Menlo`, `monospace` for mono) and not load external fonts.
A self-hosted font can be added later inside `assets/`.

### Tailwind v4 + daisyUI theme setup

In `assets/css/app.css`:

- **Keep** the daisyUI `@plugin "daisyui/packages/bundle/daisyui"` import (set `themes: false` so
  no built-in themes leak in).
- **Replace** the two bundled `@plugin ".../daisyui-theme"` blocks (the stock `dark` and `light`
  themes) with a single custom `sona` theme: `name: "sona"`, `default: true`, `prefersdark: false`,
  `color-scheme: "light"`. Map daisyUI's semantic tokens to the Sona palette so every `btn-primary`,
  `input`, `alert`, `card`, `bg-base-*`, `text-base-content`, `text-error`, etc. renders in Sona
  colors with no per-component restyling:

  | daisyUI token | Sona value | Notes |
  |---------------|------------|-------|
  | `--color-base-100` | `#fafaf9` (stone-50) | Page background |
  | `--color-base-200` | `#f5f5f4` (stone-100) | Cards, invite URL well |
  | `--color-base-300` | `#e7e5e4` (stone-200) | Borders, dividers |
  | `--color-base-content` | `#1c1917` (stone-900) | Body text, headings |
  | `--color-primary` | `#0d9488` (teal) | Primary buttons, links, focus |
  | `--color-primary-content` | `#ffffff` | Text on primary |
  | `--color-secondary` | `#bef264` (lime-dark) | Secondary CTAs (use sparingly) |
  | `--color-secondary-content` | `#1c1917` (stone-900) | Text on secondary |
  | `--color-accent` | `#3b82f6` (blue) | Accent badges/info |
  | `--color-accent-content` | `#ffffff` | Text on accent |
  | `--color-neutral` | `#57534e` (stone-600) | Muted surfaces |
  | `--color-neutral-content` | `#fafaf9` | Text on neutral |
  | `--color-error` | `#dc2626` (red-600) | Warm error red |
  | `--color-error-content` | `#ffffff` | Text on error |
  | `--radius-box` | `0.75rem` | `rounded-xl` cards |
  | `--radius-field` | `0.5rem` | `rounded-lg` inputs/buttons |
  | `--radius-selector` | `0.5rem` | Checkboxes/selects |

  daisyUI v5 accepts any CSS color (hex is fine); the existing themes use `oklch(...)`, so convert
  the hex values to oklch if you want daisyUI's generated hover/shade steps to match the theme
  generator's output. Hex is acceptable for a first pass.

- **Keep** `@import "tailwindcss" source(none);`, `@plugin "../vendor/heroicons";`, the colocated
  `@source` lines, and the LiveView loading `@custom-variant` blocks.
- **Remove** the `dark` `@custom-variant` (`&:where([data-theme=dark], ...)`) because the theme
  toggle and theme script are being deleted — we ship a single light theme.
- **Add** a small `@theme` block exposing the raw Sona colors as Tailwind utilities
  (`--color-sona-teal`, `--color-sona-lime`, `--color-sona-stone-100`, …) for the handful of places
  daisyUI's semantic tokens don't cover the design (e.g. a lime avatar fill `bg-sona-lime`, or an
  explicit `border-sona-stone-200`). Most styling should go through daisyUI semantic classes; use
  `sona-*` utilities only when there's no clean semantic equivalent.
- Define CSS variables for the single light theme in `:root`. Remove the dark-mode script and
  theme toggle from `root.html.heex` and `Layouts.app`.
- No `@apply`; every bespoke bit gets utility classes directly.

### Components

`lib/sona_web/components/core_components.ex`:

- **`<.button>`** — widen the `variant` validator to `~w(primary secondary)`. `primary` renders
  `btn btn-primary` (teal via the Sona theme); `secondary` renders `btn btn-outline` (a bordered,
  low-emphasis button that picks up stone/teal from the theme); `nil` renders plain `btn`. Update
  existing raw `<button class="btn btn-primary ...">` callers in `HomeLive`, `JoinLive`, and
  `InboxLive` to use `<.button variant="primary">` / `<.button variant="secondary">` so the
  variant mapping is centralised (done in the page-styling issue, not here).
- **`<.input>` / `<.select>` / `<.textarea>` / `<.checkbox>`** — keep the daisyUI `input`, `select`,
  `textarea`, `checkbox`, `fieldset`, `label` classes; they auto-theme to stone borders + teal
  focus rings + warm-red error state via the Sona theme. Keep the `input-error` / `select-error` /
  `textarea-error` / `text-error` classes (they now render in `#dc2626`). Preserve the `field`,
  `label`, `errors` API. If a specific field needs to override class, remember AGENTS.md: overriding
  `<.input>`'s class inherits no defaults — fully style it.
- **`<.flash>` / `<.flash_group>`** — keep `toast`, `alert`, `alert-info`, `alert-error`; they
  auto-theme. Keep `JS.show`/`JS.hide` transitions.
- **`<.table>` / `<.list>` / `<.header>`** — keep daisy classes (`table-zebra`, `list-row`,
  `base-content`, `text-base-content/70`); they auto-theme.

`lib/sona_web/components/layouts.ex`:

- **`<Layouts.app>`** — new app header:
  - Left: Sona text wordmark (e.g. `<span class="font-semibold tracking-tight">Sona.</span>`). No Phoenix logo/version.
  - Right: compact user/company label read from `@current_scope.user.username` and
    `@current_scope.company.name` (e.g. "alice @ Test Hotel") and a sign-out affordance wired to
    the existing `DELETE /session` route via `SessionController.delete/2` (HTML `<a>` can't do
    DELETE natively — use a small `<form method="post">` with `phx-method="delete"` or equivalent).
  - Remove "Website", "GitHub", "Get Started" links.
  - No theme toggle; single light theme only.
  - Main content area: full-bleed on mobile, `max-w-2xl` centered on desktop, reduced vertical
    padding so forms and chat feel like a native app shell.
- **`<.flash_group>`** stays in this module only.

`lib/sona_web/components/layouts/root.html.heex`:

- Change `<.live_title default="Sona" suffix=" · Phoenix Framework" …>` to remove the
  "Phoenix Framework" suffix.
- Remove the existing `data-theme` inline `<script>`; we are shipping a single light theme (the
  Sona daisyUI theme is `default: true`, so no runtime theme selection is needed).
- Do not add any new external `<link>` or `<script>` tags.

### Page-specific styling notes

`lib/sona_web/live/home_live.ex`:

- Centered card on desktop, full-width padding on mobile.
- Teal primary submit button (via `<.button variant="primary">`), daisyUI inputs, Sona wordmark
  above the heading.
- Keep the raw HTML `<form action="/session" method="POST">` pattern; this styling pass does not
  refactor it to `<.form>`. Pass `class="w-full"` through `<.button>` (overriding its class inherits
  no defaults per AGENTS.md — style fully if adding more than `w-full`).

`lib/sona_web/live/join_live.ex`:

- Same form styling as Home.
- Invalid-token state uses the themed `text-error` (warm red) instead of raw `text-red-600`.

`lib/sona_web/live/inbox_live.html.heex`:

- Company header becomes an eyebrow label (mono/uppercase) + large company name.
- Invite-link card uses `bg-base-200` (stone-100) with a rounded border and a "copy" icon button.
- "New group" / "New message" use the primary/secondary button components.
- Room list cards use `card bg-base-100 border border-base-300 rounded-xl` and a circular avatar
  initial in `bg-sona-lime` (lime isn't a daisyUI surface, so use the raw `sona-*` utility) or
  `bg-base-200`.

`lib/sona_web/live/room_live.html.heex`:

- Header made sticky at the top with a back arrow and room/DM partner name (current code is a
  non-sticky flex column — this pass makes it sticky).
- Remove hard-coded `indigo-600`/`gray-100`; own messages use `bg-primary text-primary-content`
  (teal via theme), others use `bg-base-200 text-base-content` (stone-100). Keep the full-height
  `dvh` layout and stream-based message list.
- Composer: `bg-base-100` with a top border, rounded input + teal send button (`btn btn-primary`).

### Dependency changes

- **Keep** `{:daisyui, ...}` in `mix.exs` (v5, Tailwind v4 plugin). No dependency changes.

### Tests

The existing tests rely on IDs and text content, so most will continue to pass. Update only tests
that assert class names or the old Phoenix header. No new tests are required for a styling change,
but run the full suite with `mix precommit`.

## Implementation notes

- After retheming, search the codebase for **off-theme colors that bypass the daisyUI theme** —
  these are the real cleanup targets (not daisyUI classes):
  `rg "(indigo-600|gray-100|gray-200|text-red-600|bg-primary|btn-primary)" lib/sona_web` should
  show only intentional raw usages; replace raw `indigo-*`/`gray-*`/`text-red-600` with daisyUI
  semantic classes (`bg-primary`, `bg-base-200`, `text-error`) or `sona-*` utilities. daisyUI class
  names (`btn`, `card`, `alert`, `input`, etc.) are *expected* and should remain.
- Delete the dead marketing files: `lib/sona_web/controllers/page_controller.ex`,
  `lib/sona_web/controllers/page_html.ex`, and `lib/sona_web/controllers/page_html/home.html.heex`.
  This also removes the only other caller of `<Layouts.theme_toggle>`.
- The existing `data-theme` script in `root.html.heex` should be removed; we are shipping a single
  light theme (the Sona theme is `default: true`). Also remove the `dark` `@custom-variant` from
  `assets/css/app.css`.
- Do not reference Google Fonts in `root.html.heex`. We are using system fonts only.
- The current `topbar` progress bar is blue (`#29d`); update it to `sona-teal` (`#0d9488`) in
  `assets/js/app.js` (`assets/vendor/topbar.js` is bundled through this entry point).
- Remove the `<.theme_toggle>` usage from `Layouts.app` and then delete the `theme_toggle/1`
  function itself (it will have no callers).
- Keep the Phoenix LiveView colocated CSS import untouched.
- The default `/` route currently renders `HomeLive`; no route changes.
- `HomeLive` uses a raw HTML `<form action="/session" method="POST">`; this styling pass does not
  refactor it to `<.form>`, but restyle its inputs and button.
- Verify the exact hex values and the Sora / IBM Plex Mono font names against the live
  [sona.ai](https://www.sona.ai/) site before locking them in; treat the table above as the
  working hypothesis.

## Acceptance criteria / definition of done

- [ ] `Layouts.app` no longer shows the Phoenix logo, version string, "Website", "GitHub", or
      "Get Started" links.
- [ ] `Layouts.app` shows a Sona wordmark and a user/company affordance.
- [ ] No theme toggle is shown; the app ships a single light theme.
- [ ] `<.flash_group>` remains only in `Layouts`.
- [ ] `root.html.heex` page title no longer uses the "Phoenix Framework" suffix.
- [ ] `assets/css/app.css` defines a single custom `sona` daisyUI theme (default light) mapped to
      the Sona palette, and the stock `dark`/`light` daisyUI themes are gone.
- [ ] The `dark` `@custom-variant` is removed from `assets/css/app.css`.
- [ ] The dead Phoenix marketing page files (`PageController`, `PageHTML`, `page_html/home.html.heex`) are deleted.
- [ ] `mix.exs` still lists `:daisyui` (v5); no dependency changes.
- [ ] `CoreComponents` (`button`, `input`, `flash`, `table`, `list`, `header`) render in Sona colors
      via the theme; `<.button>` supports `primary`/`secondary` variants.
- [ ] `HomeLive`, `JoinLive`, `InboxLive`, and `RoomLive` use Sona colors and spacing via daisyUI
      semantic classes (+ `sona-*` utilities where needed); no hard-coded `indigo-*`/`gray-*`/raw
      `text-red-600` color classes remain.
- [ ] `RoomLive` remains full-height on mobile; own/others message bubbles use the brand palette.
- [ ] No external `src`/`href` references are added to `root.html.heex`.
- [ ] Manual visual check at ~390px width (e.g. responsive dev-tools preset) passes for
      `/`, `/join/:token`, `/chats`, and `/chats/:id`: no horizontal scroll, sticky composer does
      not overlap messages, tap targets are at least 44×44 px, and all text has sufficient
      contrast.
- [ ] `mix precommit` passes (compile, format, credo, tests).

## Decisions made

| Question | Decision |
|----------|----------|
| daisyUI | **Keep it.** Retheme to a custom `sona` daisyUI theme; do not strip classes or drop the dep. daisyUI is Tailwind under the hood. |
| Theme | Single light `sona` theme (`default: true`); no dark-mode toggle or script. |
| Primary CTA colour | Teal (`#0d9488`) for primary actions; lime (`#d9f99d`) reserved for accents/avatars. |
| Logo | Text wordmark (`Sona.` — including the trailing period) for now; no external logo asset. |
| Fonts | System font stack only; no external font requests. |
| Dead marketing page | Delete `PageController`, `PageHTML`, and `page_html/home.html.heex` (`/` is handled by `HomeLive`). |
