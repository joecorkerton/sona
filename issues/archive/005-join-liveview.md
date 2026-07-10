---
id: 005
title: Join via company share link (LiveView)
status: done
created: 2026-07-10
depends_on: [002, 003]
---

## Goal
Staff onboarding via invite: a teammate opens `/join/:token`, sees the company name, picks a username unique to that company, and lands in the chat (re-entering with the same username restores identity and history).

## Context
See `plans/basic-chat-poc.md` sections "High-level user flows B" (lines 38–44), "LiveView surfaces" (lines 183–196), and "Chunk 5" (lines 331–339).

Critical constraints:
- Route `/join/:token` → `JoinLive`.
- Show company name; handle invalid token UX.
- Username form → **POST to `SessionController :join`** (`POST /join/:token/session`, HTTP), which calls `Accounts.get_or_create_user/2` then `Chat.add_to_general/1`, sets the `user_id` cookie, redirects to `/chats` or `/chats/<general_id>`. Do **not** set the session from the LiveView.
- Same username again → `get_or_create_user` returns the existing row (restores identity/history).
- A session user opening a **different** company's invite link: the controller **overwrites** `user_id` with the new user (POC simplest).
- Mobile-first; `<Layouts.app>` with `current_scope` pass-through; `to_form/2` + unique form id.

## Acceptance criteria
- [x] Route `/join/:token` → `SonaWeb.JoinLive`
- [x] LiveView shows the company name for the token
- [x] Invalid token UX (e.g. error message / redirect) — no crash
- [x] Username form with unique DOM id; submit POSTs to `SessionController.join` (HTTP)
- [x] LiveView does not write the session
- [x] On success: `user_id` cookie set; redirect to `/chats` (or `/chats/<general_id>`)
- [x] Re-joining with the same username restores the same user (no duplicate row)
- [x] User lands in General room (added via `Chat.add_to_general/1`)
- [x] Already-logged-in user joining another company overwrites the session (`user_id` becomes the new user)
- [x] Template starts with `<Layouts.app>` with `current_scope` passed through
- [x] Forms built with `to_form/2`; unique form id
- [x] LiveView tests: username form POSTs to controller; second join same username loads same user/history; invalid token UX; cross-company overwrite

## Notes
- 2026-07-10: started implementation — adding route, JoinLive module, template, and tests
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
- 2026-07-10: review fix — SessionController.join/2 now validates nil/blank username, handles {:error, changeset} from get_or_create_user, and handles {:error, :no_general_room} from add_to_general; template uses <.link navigate> instead of <a>; test uses has_element? instead of raw HTML assertion