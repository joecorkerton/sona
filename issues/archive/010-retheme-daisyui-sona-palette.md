---
id: 010
title: Retheme daisyUI to the Sona palette
status: done
created: 2026-07-10
depends_on: [009]
---

## Goal
Replace daisyUI's stock light/dark themes with a single custom `sona` theme mapped to the Sona
palette, so every daisyUI component class (`btn`, `input`, `alert`, `card`, `bg-base-*`,
`text-base-content`, `text-error`, …) renders in Sona colors automatically. Keep daisyUI and
its dependency; do not strip classes or drop the dep. Also expose a small set of raw `sona-*`
Tailwind utilities for colors daisyUI's semantic tokens don't cover.

## Context
See `plans/app-styling-branding.md` sections "Brand palette", "Tailwind v4 + daisyUI theme
setup", and "Dependency changes", plus implementation notes on the topbar color and the `dark`
custom-variant removal.

This is the foundational issue for the styling/branding pass (010–014). It gates the component
work (011), the app shell (012), page styling (013), and the verification gate (014), because
nothing downstream can be *verified* against Sona colors until the theme tokens land. `009`
(layout/seeds/precommit) is treated as a satisfied prerequisite per the plan's framing that the
chat POC is functionally in place.

Current state (verified against the code): `assets/css/app.css` imports daisyUI via
`@plugin "daisyui/packages/bundle/daisyui" { themes: false; }` and defines two inline themes
(`@plugin "daisyui/packages/bundle/daisyui-theme"` for `dark` and `light`, in `oklch`).
`mix.exs` lists `{:daisyui, github: "saadeghi/daisyui", …}` (v5 / Tailwind v4 plugin).
`assets/js/app.js` sets `barColors: {0: "#29d"}`.

Critical constraints (from `AGENTS.md`):
- Tailwind v4, no `tailwind.config.js`; keep `@import "tailwindcss" source(none);`.
- daisyUI is allowed; retheme it to the project palette (Tailwind under the hood).
- No `@apply` in raw CSS — write utilities out directly.
- Only `app.css` and `app.js` are bundled; no external `src`/`href` in layouts.
- No new Elixir dependencies; **keep** `:daisyui`.

## Acceptance criteria
- [x] `assets/css/app.css` keeps `@plugin "daisyui/packages/bundle/daisyui"` (`themes: false`)
- [x] `assets/css/app.css` replaces the two stock `@plugin ".../daisyui-theme"` blocks (`dark`
      and `light`) with a single custom `sona` theme: `name: "sona"`, `default: true`,
      `prefersdark: false`, `color-scheme: "light"`
- [x] The `sona` theme maps daisyUI semantic tokens to the Sona palette: `--color-base-100`
      `#fafaf9`, `--color-base-200` `#f5f5f4`, `--color-base-300` `#e7e5e4`, `--color-base-content`
      `#1c1917`, `--color-primary` `#0d9488`, `--color-primary-content` `#ffffff`,
      `--color-secondary` `#bef264`, `--color-secondary-content` `#1c1917`, `--color-accent`
      `#3b82f6`, `--color-accent-content` `#ffffff`, `--color-neutral` `#57534e`,
      `--color-neutral-content` `#fafaf9`, `--color-error` `#dc2626`, `--color-error-content`
      `#ffffff`, `--radius-box` `0.75rem`, `--radius-field` `0.5rem`, `--radius-selector`
      `0.5rem` (daisyUI v5 accepts hex; convert to oklch if generated shades must match the
      generator)
- [x] `assets/css/app.css` removes the `dark` `@custom-variant`
      (`@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *))`) — single light
      theme only
- [x] `assets/css/app.css` adds a small `@theme` block exposing raw Sona utilities
      (`--color-sona-teal` `#0d9488`, `--color-sona-teal-dark` `#0f766e`, `--color-sona-lime`
      `#d9f99d`, `--color-sona-lime-dark` `#bef264`, `--color-sona-blue` `#3b82f6`,
      `--color-sona-stone-50` `#fafaf9`, `--color-sona-stone-100` `#f5f5f4`,
      `--color-sona-stone-200` `#e7e5e4`, `--color-sona-stone-600` `#57534e`,
      `--color-sona-stone-900` `#1c1917`, `--color-sona-dark` `#0f172a`) for the handful of cases
      daisyUI semantic tokens don't cover (e.g. lime avatar fills)
- [x] `@import "tailwindcss" source(none);`, the heroicons `@plugin`, the colocated `@source`
      lines (including the `_build/.../phoenix-colocated` one), and the LiveView loading
      `@custom-variant` blocks (`phx-click-loading`, `phx-submit-loading`,
      `phx-change-loading`) are preserved unchanged
- [x] No `@apply` used in `app.css`
- [x] `mix.exs` still lists `{:daisyui, ...}` (v5); no dependency changes
- [x] Topbar progress bar color set to Sona teal (`#0d9488`) in `assets/js/app.js` (was `#29d`)
- [x] No new Elixir dependencies added

## Notes
- 2026-07-10: created from `plans/app-styling-branding.md` as "strip daisyUI"; renamed and
  rewritten the same day after the user corrected AGENTS.md to allow daisyUI. New approach:
  retheme, don't strip. Verified current daisyUI wiring (v5, inline themes in app.css, dep in
  mix.exs) before rewriting.
- 2026-07-11: started implementation — replace stock light/dark daisyUI themes with single `sona` theme + `@theme` utilities + topbar teal.
- 2026-07-11: landed `assets/css/app.css` single `sona` daisyUI theme (hex palette + radii),
  `@theme` sona-* utilities, removed dark `@custom-variant`; topbar barColors → `#0d9488` in
  `assets/js/app.js`. Also mapped info/success/warning to palette so daisyUI states stay on-brand.
- 2026-07-11: completed — all acceptance criteria met; mix precommit clean (credo clean, 113 tests passed).
