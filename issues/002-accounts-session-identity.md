---
id: 002
title: Accounts context + session identity
status: todo
created: 2026-07-10
depends_on: [001]
---

## Goal
Company + username identity with a session cookie, written by an HTTP controller (never from a LiveView), with company scoped uniqueness and concurrent-join safety.

## Context
See `plans/basic-chat-poc.md` sections "Identity model" (lines 58–65), "Session / auth" (lines 167–179), "Critical files" (lines 254–270), and "Chunk 2" (lines 292–302).

Critical constraints:
- LiveView sockets expose the session read-only; `put_session` must happen in an HTTP controller (`SonaWeb.SessionController`), not a LiveView.
- `create_company/1` creates Company (with `invite_token`; **accepts optional `:invite_token` override** so seeds/tests can pin a known token) + creator User in one transaction. Returns `{company, user}`. **Does not call Chat** — the controller wires `Chat.ensure_default_room/2` after.
- `get_or_create_user(company, username)` must `rescue Ecto.ConstraintError` on the `(company_id, username)` unique index and re-fetch to handle concurrent same-username joins.
- `SonaWeb.UserAuth` `on_mount` only: `:mount_current_user` reads cookie + preloads `:company` and assigns `current_user` / `current_scope` (`%{user: user, company: user.company}`); `:require_user` redirects to `/` or `/join/:token` if missing. **Does not write the session.**
- `SonaWeb.SessionController`: `create/2` (create-company → `Accounts.create_company/1` + `Chat.ensure_default_room/2` → set cookie → redirect `/chats`), `join/2` (join → `Accounts.get_or_create_user/2` + `Chat.add_to_general/1` → set cookie → redirect `/chats`), optional `delete/2`. Uses `Plug.Conn.put_session(conn, "user_id", id)` then `redirect`.
- Test helper `log_in_user(conn, user)` sets the session cookie directly via `Plug.Test.init_test_session`.
- Two `live_session` blocks in the router (`:current_user` wraps `/chats*`; `:guest` wraps `/`, `/join/:token`), both `on_mount: [{UserAuth, :mount_current_user}]`.

## Acceptance criteria
- [ ] `Sona.Accounts.create_company/1` creates company + creator user in one transaction; accepts optional `:invite_token` override; returns `{company, user}`; does not call Chat
- [ ] `Sona.Accounts.get_company_by_invite_token/1` exists
- [ ] `Sona.Accounts.get_or_create_user/2` rescues `Ecto.ConstraintError` and re-fetches on concurrent same-username join
- [ ] `SonaWeb.UserAuth` `on_mount :mount_current_user` reads the `user_id` cookie, preloads `:company`, assigns `current_user` and `current_scope`
- [ ] `SonaWeb.UserAuth` `:require_user` redirects when `current_user` is missing
- [ ] `SonaWeb.UserAuth` never writes the session
- [ ] `SonaWeb.SessionController.create/2` calls `Accounts.create_company/1` + `Chat.ensure_default_room/2`, sets `user_id` cookie, redirects to `/chats`
- [ ] `SonaWeb.SessionController.join/2` calls `Accounts.get_or_create_user/2` + `Chat.add_to_general/1`, sets `user_id` cookie, redirects to `/chats`
- [ ] (optional) `SonaWeb.SessionController.delete/2` clears the `user_id` cookie
- [ ] Router wires `POST /session`, `POST /join/:token/session`, and two `live_session` blocks (`:current_user` over `/chats*`; `:guest` over `/` and `/join/:token`)
- [ ] Test helper `log_in_user(conn, user)` sets the session cookie directly
- [ ] Context tests: company create, concurrent same-username → one user, same username in two companies succeeds
- [ ] Controller test: `POST /session` sets cookie and redirects to `/chats`; session mount assigns `current_user`/`current_scope`