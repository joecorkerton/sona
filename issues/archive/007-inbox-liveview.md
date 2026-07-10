---
id: 007
title: Inbox / room list LiveView
status: done
created: 2026-07-10
depends_on: [002, 003]
---

## Goal
Navigate chats and surface the company invite link: a user opens `/chats`, sees the rooms they're in (last activity first), the company name + shareable invite URL, and entry points to start a new group or DM.

## Context
See `plans/basic-chat-poc.md` sections "High-level user flows D" (lines 52–56), "LiveView surfaces" (lines 183–196), and "Chunk 7" (lines 352–360).

Critical constraints:
- Route `/chats` → `InboxLive` under `:current_user` live_session.
- List user's rooms (company-implied via `Sona.Chat.list_rooms_for_user/1`); empty state.
- Show company name + shareable invite URL (`/join/:token`) — primary share affordance.
- Entry points: "New group", "New message" (wired in issue 008).
- Mobile-first; `<Layouts.app>` with `current_scope` pass-through.

## Acceptance criteria
- [x] Route `/chats` → `SonaWeb.InboxLive` under the `:current_user` live_session
- [x] Lists the current user's rooms (via `Sona.Chat.list_rooms_for_user/1`); does not cross companies
- [x] Empty state shown when the user has no rooms
- [x] Company name displayed
- [x] Shareable invite URL `/join/:token` visible (primary share affordance)
- [x] Entry points present: "New group", "New message"
- [x] Rooms link to `/chats/:room_id`
- [x] Template starts with `<Layouts.app>` with `current_scope` passed through
- [x] Layout usable at phone width (~390px)
- [x] LiveView tests: list renders after fixtures; invite URL visible; empty state — via element assertions

## Notes
- 2026-07-10: started implementation — adding InboxLive module + template + route under :current_user live_session, then tests via element assertions
- 2026-07-10: InboxLive created at `lib/sona_web/live/inbox_live.ex` + template `lib/sona_web/live/inbox_live.html.heex`; route `/chats` wired to `InboxLive :index` in the `:current_user` live_session (inherits `:require_user`). `mount/3` loads rooms via `Chats.list_rooms_for_user/1` (then re-preloads `memberships: [:user]`) and precomputes a display name + initial for each room (group: `room.name`; direct: other user's `display_name`/`username`). Template renders company header, shareable invite URL via `SonaWeb.Endpoint.url()`, New group / New message entry points (visual only — wired in 008), room list linking to `/chats/:id`, and empty state. Tests at `test/sona_web/live/inbox_live_test.exs` cover: rendering for logged-in user, redirect for unauthenticated, company header, invite URL with token, both entry points, room listing, room links, no cross-company bleed, direct-room name shows the other user, empty state. 12 inbox tests + full suite 100 tests passing; `mix precommit` clean.
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
- 2026-07-10: review fix — convert @rooms to a LiveView stream (AGENTS.md: streams not lists for collections) and switch the html =~ "Test Hotel" assertion to has_element? (AGENTS.md: assert on elements, never raw HTML)
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
