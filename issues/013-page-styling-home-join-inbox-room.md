---
id: 013
title: Page styling for Home, Join, Inbox, Room
status: todo
created: 2026-07-10
depends_on: [012]
---

## Goal
Apply Sona colors, spacing, and rounded cards to the four LiveView pages (Home, Join, Inbox,
Room) using the Sona daisyUI theme (010) and restyled components (011), inside the Sona app
shell (012). Use daisyUI semantic classes (`bg-primary`, `bg-base-200`, `border-base-300`,
`text-base-content`, `text-error`, …) plus `sona-*` utilities where daisyUI's tokens don't
cover the design (e.g. lime avatars).

## Context
See `plans/app-styling-branding.md` section "Page-specific styling notes" and
"Product / user flows".

Dependency/sequencing note: `008` (New group + 1-1 DM flows) modifies the `InboxLive` and
`RoomLive` templates. This issue styles the current POC templates; if `008` lands later,
re-apply this styling to its additions (or sequence this issue after `008` to avoid rework).
`008` is **not** a hard dependency — the plan styles the existing POC and explicitly does not
add chat features.

Current state (verified): HomeLive has `id="new-company-form"` raw form + `<button type="submit"
class="btn btn-primary w-full">`. JoinLive uses `btn btn-primary w-full`, `text-base-content/70`,
`bg-primary`, `text-red-600` (raw). InboxLive uses `text-base-content/60/70`, `border-base-300`,
`bg-base-100/200`, `btn btn-primary`, raw `btn`. RoomLive uses `border-gray-200`, `bg-white`,
`bg-indigo-600 text-white`, `bg-gray-100 text-gray-900`, raw `bg-indigo-600` send button. All
four pages already start with `<Layouts.app ... current_scope={@current_scope}>`.

Critical constraints (from `AGENTS.md`):
- Mobile-first (~390px), still usable on desktop.
- Always use LiveView streams (not lists) for collections; InboxLive room list and RoomLive
  messages are streams.
- Keep page DOM IDs intact so tests keep passing (update only class/text assertions as needed).
- `HomeLive` uses a raw HTML `<form action="/session" method="POST">`; this styling pass does
  **not** refactor it to `<.form>` — only restyle its inputs/button.

## Acceptance criteria
- [ ] `HomeLive` (`/`): centered card on desktop, full-width padding on mobile; Sona wordmark
      above the heading; raw `<form action="/session" method="POST">` preserved; raw
      `<button type="submit" class="btn btn-primary w-full">` → `<.button variant="primary">`
      — pass `class="w-full"` through (per AGENTS.md, overriding `<.button>` class inherits no
      defaults, so style fully if adding more than `w-full`)
- [ ] `JoinLive` (`/join/:token`): same form styling as Home; invalid-token state uses the
      themed `text-error` (warm red) instead of raw `text-red-600`
- [ ] `InboxLive` (`/chats`): company header as eyebrow (mono/uppercase) + large company name;
      invite-link card `bg-base-200` (stone-100) with rounded border and a copy icon button;
      "New group" / "New message" use `<.button variant="primary">` /
      `<.button variant="secondary">`; room list cards `card bg-base-100 border border-base-300
      rounded-xl` with a circular avatar initial (`bg-sona-lime` or `bg-base-200`); room list
      remains a LiveView stream
- [ ] `RoomLive` (`/chats/:id`): header made sticky at the top with a back arrow + room/DM
      partner name (current code is a non-sticky flex column — this criterion makes it sticky,
      not just preserves stickiness); own messages `bg-primary text-primary-content` (teal via
      theme), others `bg-base-200 text-base-content` (stone-100); no hard-coded
      `indigo-600`/`gray-100`/`bg-white`/`border-gray-200`; composer `bg-base-100` + top border +
      rounded input + `btn btn-primary` send button; full-height `dvh` layout and stream-based
      message list preserved
- [ ] No off-theme raw color classes remain in these four templates (`indigo-*`, `gray-*`,
      raw `text-red-600`, raw `bg-primary`/`btn-primary` where a `<.button variant>` applies);
      daisyUI semantic classes and `sona-*` utilities are expected and should remain

## Notes
- 2026-07-10: created from `plans/app-styling-branding.md` (page-specific styling notes).
  Rewritten the same day after the user allowed daisyUI: targets are now daisyUI semantic
  classes + `sona-*` utilities, not plain-Tailwind replacements. Coordinate with 008's
  InboxLive/RoomLive template changes — not hard-blocked, but re-apply this styling to anything
  008 adds.
