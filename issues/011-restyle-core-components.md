---
id: 011
title: Adopt Sona daisyUI theme in CoreComponents + add button variants
status: todo
created: 2026-07-10
depends_on: [010]
---

## Goal
Centralise button styling by adding `primary`/`secondary` variants to `<.button>`, and verify
that all `CoreComponents` (`input`, `flash`, `table`, `list`, `header`) render correctly in Sona
colors via the custom daisyUI theme from 010. Do **not** strip daisyUI classes — they auto-theme.

## Context
See `plans/app-styling-branding.md` section "Components" (`core_components.ex`). Depends on the
Sona daisyUI theme landing in 010, because the component classes only pick up Sona colors once
the theme tokens are defined. The app shell (012) and page styling (013) consume these
components, so this issue only *defines* the button variants and confirms the components;
adopting `<.button variant="...">` in page templates belongs to 013.

Current state (verified): `core_components.ex` uses `btn`, `btn-soft`, `btn-primary`, `toast`,
`alert`, `alert-info`, `alert-error`, `fieldset`, `label`, `input`, `select`, `textarea`,
`checkbox`, `input-error`, `select-error`, `textarea-error`, `table-zebra`, `list-row`,
`base-content`, `text-base-content/70`, `text-error`. `<.button>` currently allows only
`~w(primary)`; the `nil` variant maps to `btn-primary btn-soft`. All of these auto-theme once
010 lands, so most of `core_components.ex` needs **no class changes** — the real work here is the
`secondary` button variant and a rendering verification pass.

Critical constraints (from `AGENTS.md`):
- Use `<.input>` for form fields; preserve the `field`, `label`, `errors` API.
- `<.flash_group>` only belongs in `Layouts` — keep it there.
- Icons via `<.icon name="hero-..." />`, never `Heroicons` modules directly.
- If a field overrides `<.input>`'s class, no defaults are inherited — fully style it.

## Acceptance criteria
- [ ] `<.button>` accepts `~w(primary secondary)` in the `variant` validator; `primary` renders
      `btn btn-primary` (teal via the Sona theme); `secondary` renders `btn btn-outline`
      (bordered, low-emphasis, themed); `nil` renders plain `btn`
- [ ] `<.input>` / `<.select>` / `<.textarea>` / `<.checkbox>` keep their daisyUI classes
      (`input`, `select`, `textarea`, `checkbox`, `fieldset`, `label`, `input-error`,
      `select-error`, `textarea-error`) — no stripping — and the `field`/`label`/`errors` API is
      preserved; error states render in the themed warm red (`#dc2626`) via `text-error` /
      `*-error`
- [ ] The private `error/1` helper keeps `text-error` (now warm red via the theme)
- [ ] `<.flash>` / `<.flash_group>` keep `toast`, `alert`, `alert-info`, `alert-error` (auto-
      themed); `JS.show` / `JS.hide` transitions preserved; `<.flash_group>` remains only in
      `Layouts`
- [ ] `<.table>` / `<.list>` / `<.header>` keep daisy classes (`table-zebra`, `list-row`,
      `base-content`, `text-base-content/70`) — auto-themed
- [ ] Components render correctly in Sona colors — verified by the existing page tests in
      `test/sona_web/live/*_test.exs` (no new smoke test required)

## Notes
- 2026-07-10: created from `plans/app-styling-branding.md` as "restyle without daisyUI";
  rewritten the same day after the user allowed daisyUI. Most of `core_components.ex` now needs
  no class changes — the Sona daisyUI theme (010) does the restyling. The only real code change
  here is the `secondary` button variant + a rendering verification pass. Adopting
  `<.button variant="...">` in Home/Join/Inbox raw `<button>` callers is tracked in 013.
