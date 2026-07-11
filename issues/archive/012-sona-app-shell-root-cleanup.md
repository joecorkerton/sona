---
id: 012
title: Sona app shell + root.html cleanup + dead marketing removal
status: done
created: 2026-07-10
depends_on: [011]
---

## Goal
Ship a Sona-branded app shell — wordmark header, compact user/company label
with sign-out — and remove the stock Phoenix chrome, the theme toggle, the
"Phoenix Framework" title suffix, and the dead marketing page files.

## Context
See `plans/app-styling-branding.md` sections "layouts.ex" and "root.html.heex",
and implementation notes on deleting the dead marketing files, removing
`<.theme_toggle>`, and not adding external fonts.

Scope note: `009` established the baseline `Layouts.app` (Sona + company +
username, stock nav removed, `<.flash_group>` only in Layouts). This issue
*enhances* that shell to the full new-plan spec (wordmark, user/company
affordance, sign-out, theme removal, title suffix, dead-file deletion). `009`
is treated as a satisfied prerequisite (being finished elsewhere); this issue
builds on its baseline via the 010→011 component/theme chain.

Critical constraints (from `AGENTS.md`):
- LiveView templates start with `<Layouts.app flash={@flash} current_scope={@current_scope} ...>`.
- `<.flash_group>` only in `Layouts`.
- No raw `<script>` in HEEx; no external `src`/`href` in layouts.
- No `live_redirect`/`live_patch`; use `<.link navigate={...}>` / `push_navigate`.
- Sign-out goes through the existing `DELETE /session` route
  (`SessionController.delete/2`).

## Acceptance criteria
- [x] `Layouts.app` shows a Sona wordmark (e.g. `Sona.`) on the left; no Phoenix
      logo or version string
- [x] `Layouts.app` shows a compact user/company label read from
      `@current_scope.user.username` and `@current_scope.company.name` (e.g.
      "alice @ Test Hotel") and a sign-out affordance wired to `DELETE /session`
      (note: HTML `<a>` can't do DELETE natively — use a small `<form
      method="post">` with `phx-method="delete"` or equivalent; the route
      `delete "/session", SessionController, :delete` already exists)
- [x] `Layouts.app` no longer shows "Website", "GitHub", or "Get Started" links
- [x] No theme toggle is shown; `<.theme_toggle>` usage removed from
      `Layouts.app` and the `theme_toggle/1` function deleted (no remaining
      callers)
- [x] Main content area is full-bleed on mobile, `max-w-2xl` centered on
      desktop, with reduced vertical padding
- [x] `<.flash_group>` remains only in `Layouts`
- [x] `root.html.heex` `<.live_title>` no longer uses the "Phoenix Framework"
      suffix (default `Sona`)
- [x] `root.html.heex` `data-theme` inline `<script>` removed (single light
      theme); no external `<link>`/`<script>` added; no Google Fonts referenced
- [x] Dead marketing files deleted: `lib/sona_web/controllers/page_controller.ex`,
      `lib/sona_web/controllers/page_html.ex`,
      `lib/sona_web/controllers/page_html/home.html.heex`
- [x] No router changes (`/` still handled by `HomeLive`)

## Notes
- 2026-07-10: created from `plans/app-styling-branding.md` (layouts.ex,
  root.html.heex, dead marketing removal). Overlaps 009's layout/flash_group
  criteria by design — 009 set the baseline, this issue takes it to the full
  new-plan spec.
- 2026-07-11: started implementation — enhance Layouts.app shell (wordmark,
  user/company label, sign-out), remove theme toggle + root theme script,
  confirm dead marketing files already gone.
- 2026-07-11: Layouts.app — `Sona.` wordmark (`#sona-wordmark`),
  `{username} @ {company}` label (`#user-company-label`), sign-out form
  POST + `_method=delete` to `/session` (`#sign-out-form`); theme_toggle/1
  deleted; main `max-w-2xl` with reduced `py-3`/`sm:py-4`. root.html.heex —
  default title `Sona`, theme script removed. Dead marketing files already
  absent (from 009). Tests: home guest shell + inbox signed-in shell +
  sign-out submit.
- 2026-07-11: completed — all acceptance criteria met; mix precommit clean
  (credo clean, 115 tests passed).
