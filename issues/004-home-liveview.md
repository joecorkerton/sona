---
id: 004
title: Create company (Home LiveView)
status: todo
created: 2026-07-10
depends_on: [002, 003]
---

## Goal
First-user path that establishes a company + invite link: visitor opens `/`, enters a company name + username, and lands in the app with a shareable invite URL.

## Context
See `plans/basic-chat-poc.md` sections "High-level user flows A" (lines 32–36), "LiveView surfaces" (lines 183–196), and "Chunk 4" (lines 322–329).

Critical constraints:
- Route `/` → `HomeLive` (replace stock Phoenix home page).
- Form: company name + username. On submit, **POST to `SessionController :create`** (HTTP) — do **not** set the session from the LiveView. The controller calls `Accounts.create_company/1` then `Chat.ensure_default_room/2`, sets the `user_id` cookie, redirects to `/chats`.
- If already logged in → redirect to inbox.
- Mobile-first: phone-form layout, centered max-width on desktop.
- Use `to_form/2` + unique form id; never raw changeset in template. Always `<Layouts.app flash={@flash} current_scope={@current_scope}>`.

## Acceptance criteria
- [ ] Route `/` → `SonaWeb.HomeLive` (stock Phoenix home page replaced)
- [ ] Form with company name + username fields, unique DOM id (e.g. `new-company-form`)
- [ ] Form submit POSTs to `SessionController.create` (HTTP), not a LiveView event
- [ ] LiveView does not attempt to write the session
- [ ] On success: company + invite token + General room created; `user_id` cookie set; redirect to `/chats`
- [ ] Already-logged-in visitor is redirected to `/chats`
- [ ] Template starts with `<Layouts.app flash={@flash} current_scope={@current_scope}>` and passes `current_scope` through
- [ ] Form built with `to_form/2`; no raw changeset in template
- [ ] LiveView test: submitting the form POSTs to the controller; verifies company + invite token + General room via element assertions; cookie set; redirects to `/chats`
- [ ] Layout is usable at phone width (~390px) and centered max-width on desktop