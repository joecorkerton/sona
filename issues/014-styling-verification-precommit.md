---
id: 014
title: Styling pass verification + precommit gate
status: todo
created: 2026-07-10
depends_on: [013]
---

## Goal
Final sweep and QA gate for the styling/branding pass: no off-theme raw color classes remain
anywhere in the web layer, the daisyUI theme is applied and rendering Sona colors, no external
references were added, the manual mobile visual check passes on all four routes, and
`mix precommit` is green. daisyUI class names are **expected** to remain — this is not a
"remove daisyUI" sweep.

## Context
See `plans/app-styling-branding.md` section "Acceptance criteria / definition of done" and
implementation notes on the off-theme color sweep. This issue is the integration gate for
010–013; it depends on the page styling landing (013, which transitively covers 010–012).

Critical constraints (from `AGENTS.md`):
- `mix precommit` is the done-state gate (compile, format, credo, tests).
- Tests assert on elements/IDs, never raw HTML; update only tests that assert old class names
  or the Phoenix header.
- Mobile-first design target ~390px.

## Acceptance criteria
- [ ] `rg "(indigo-600|gray-100|gray-200|text-red-600)" lib/sona_web` returns no matches — these
      are the off-theme raw colors that bypass the daisyUI theme and must be replaced with
      daisyUI semantic classes (`bg-primary`, `bg-base-200`, `text-error`) or `sona-*` utilities
- [ ] daisyUI classes are expected and present (not swept): a spot check of
      `rg "(btn|alert|toast|card|input|select|textarea|checkbox|fieldset|navbar|badge)" lib/sona_web`
      shows daisyUI classes in use and rendering in Sona colors via the `sona` theme
- [ ] `assets/css/app.css` defines the single `sona` daisyUI theme and no stock `dark`/`light`
      daisyUI themes remain
- [ ] No external `src`/`href` references were added in `root.html.heex` (fonts, CDN, scripts);
      the two `phx-track-static` `/assets/...` references are internal and fine
- [ ] Manual visual check at ~390px width passes for `/`, `/join/:token`, `/chats`, and
      `/chats/:id`: no horizontal scroll, sticky composer does not overlap messages, tap targets
      are at least 44×44px, and all text has sufficient contrast
- [ ] `mix precommit` passes (compile, format, credo, tests)
- [ ] Existing tests pass; only tests asserting old class names or the Phoenix header were
      updated

## Notes
- 2026-07-10: created from `plans/app-styling-branding.md` (definition of done, sweep note).
  Rewritten the same day after the user allowed daisyUI: the sweep target flipped from "no
  daisyUI classes" to "no off-theme raw color classes that bypass the theme." daisyUI classes
  are expected to remain.
