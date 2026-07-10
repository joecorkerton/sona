---
id: 007
title: Inbox / room list LiveView
status: todo
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
- [ ] Route `/chats` → `SonaWeb.InboxLive` under the `:current_user` live_session
- [ ] Lists the current user's rooms (via `Sona.Chat.list_rooms_for_user/1`); does not cross companies
- [ ] Empty state shown when the user has no rooms
- [ ] Company name displayed
- [ ] Shareable invite URL `/join/:token` visible (primary share affordance)
- [ ] Entry points present: "New group", "New message"
- [ ] Rooms link to `/chats/:room_id`
- [ ] Template starts with `<Layouts.app>` with `current_scope` passed through
- [ ] Layout usable at phone width (~390px)
- [ ] LiveView tests: list renders after fixtures; invite URL visible; empty state — via element assertions