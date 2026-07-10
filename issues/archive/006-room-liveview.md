---
id: 006
title: Room chat LiveView (core chat + realtime)
status: done
created: 2026-07-10
depends_on: [002, 003]
---

## Goal
The messaging experience: a user opens a room `/chats/:id`, sees the streamed message history, and sends text that every open client (including the sender) inserts exactly once via PubSub.

## Context
See `plans/basic-chat-poc.md` sections "High-level user flows C" (lines 46–50), "Realtime contract" (lines 197–221), "LiveView surfaces" (lines 183–196), and "Chunk 6" (lines 341–350).

Critical constraints (single-insert-per-receiver rule):
- Route `/chats/:id` → `RoomLive`. `require_user` + membership + `room.company_id == current_user.company_id`.
- Messages as **LiveView streams** (`phx-update="stream"`), not lists; empty state via Tailwind `hidden only:block`; track empty state in a separate assign (streams have no count).
- Subscribe on `connected?(socket)` via `Chat.subscribe_room/1`.
- On `handle_event("send", ...)`: call `Chat.send_message/3`, **do NOT `stream_insert` here** — clear composer and rebind socket. The message arrives via `handle_info({:new_message, msg})`.
- `handle_info({:new_message, msg}, socket)`: `stream_insert(socket, :messages, msg, at: -1)` and rebind. Each client inserts exactly once.
- Header: group name, or the other user's name for DMs.
- Mobile full-height column: header / scrollable messages / sticky composer.

## Acceptance criteria
- [x] Route `/chats/:id` → `SonaWeb.RoomLive` under the `:current_user` live_session
- [x] `RoomLive` requires a user and verifies membership + `room.company_id == current_user.company_id`
- [x] Other-company room id is rejected (redirect / error, not shown)
- [x] Non-member cannot open or send in the room
- [x] Messages rendered as a LiveView stream (`phx-update="stream"`), with a DOM id on the parent and each child using the stream id
- [x] Empty state shown via `hidden only:block` (separate count assign)
- [x] Compose box is sticky at the bottom; form built with `to_form/2` and a unique DOM id
- [x] On send: calls `Chat.send_message/3`; **does not `stream_insert` locally**; clears composer and rebinds socket
- [x] Message inserted exactly once per client via `handle_info({:new_message, msg})` → `stream_insert(..., at: -1)`
- [x] Sender sees its own message exactly once (no duplicate from local insert)
- [x] Open in two clients → both see each other's messages in realtime
- [x] Header shows group name or the other user's name for DMs
- [x] Own messages aligned to one side; others show author name (important in groups)
- [x] Template starts with `<Layouts.app>` with `current_scope` passed through
- [x] Layout usable at phone width (~390px): full-height column, sticky composer
- [x] LiveView tests: sender sees message once; two clients see each other's; other-company room denied; non-member denied — all via element assertions

## Notes
- 2026-07-10: started implementation — create RoomLive module, template, route, and tests
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
- 2026-07-10: review fix — Ecto.UUID.cast/1 validation for malformed room ids; get_header_name nil fallback; added malformed-id, DM-header, and alignment tests