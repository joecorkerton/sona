---
id: 003
title: Chat context (rooms, membership, messages, DMs)
status: done
created: 2026-07-10
depends_on: [001]
---

## Goal
All chat domain operations without any UI, always company-scoped: default room, group creation, message sending with PubSub broadcast, DM find-or-create with canonical uniqueness, and company member listing.

## Context
See `plans/basic-chat-poc.md` sections "Data model" (lines 96–165), "Realtime contract" (lines 197–221), "Cross-context coordination" (lines 240–247), and "Chunk 3" (lines 304–320).

Critical constraints:
- **Chat does not call Accounts.** The HTTP controller orchestrates across Accounts↔Chat; `ensure_default_room/2` and `add_to_general/1` are called by `SessionController`, not by Accounts.
- Every API takes `%User{}` or `%Company{}` and filters by `user.company_id`. Never list rooms/messages across companies.
- `ensure_default_room(company, user)` — creates "General" `:group` room + creator membership. Called by controller after `Accounts.create_company/1`.
- `add_to_general(user)` — adds user as member of the company's General room. Called by controller after `Accounts.get_or_create_user/2`.
- `create_group_room(user, attrs)` — room with `company_id`, membership for creator (creator is sole member for POC).
- `list_rooms_for_user/1` — backed by `memberships(user_id)` index; company implied by user.
- `list_messages(room, opts)` — last N, oldest→newest.
- `send_message(room, user, attrs)` — membership + same-company checks; broadcasts `{:new_message, msg}` to `Sona.PubSub` topic `"chat:room:#{room.id}"`. **Sender is a subscriber too** — does not stream_insert locally on send.
- `find_or_create_direct_room(user_a, user_b)`:
  - reject self-DM (`{:error, :self}` if same id),
  - reject cross-company (`{:error, :cross_company}` if different `company_id`),
  - canonical `direct_token` from sorted-pair of lowercased user ids, unique-index backed,
  - rescue `Ecto.ConstraintError` and re-fetch on concurrent create.
- `list_company_users(company)` — **required** (DM picker lists company members, excludes current user).
- `subscribe_room/1` / broadcast on send.

## Acceptance criteria
- [x] `Sona.Chats.ensure_default_room/2` creates a "General" `:group` room + creator membership; idempotent
- [x] `Sona.Chats.add_to_general/1` adds the user as a member of the company's General room
- [x] `Sona.Chats.create_group_room/2` creates a `:group` room with `company_id` and creator membership (creator is sole member)
- [x] `Sona.Chats.list_rooms_for_user/1` returns the user's rooms (company-implied); does not cross companies
- [x] `Sona.Chats.list_messages/2` returns last N messages oldest→newest
- [x] `Sona.Chats.send_message/3` checks membership + same-company and broadcasts `{:new_message, msg}` to the room PubSub topic
- [x] `Sona.Chats.send_message/3` rejects non-members and cross-company users
- [x] `Sona.Chats.find_or_create_direct_room/2` rejects self-DM with `{:error, :self}`
- [x] `Sona.Chats.find_or_create_direct_room/2` rejects cross-company with `{:error, :cross_company}`
- [x] A↔B and B↔A resolve to the same room (canonical `direct_token`)
- [x] Concurrent `find_or_create_direct_room/2` (two tasks) yields one room (rescues `Ecto.ConstraintError` and re-fetches)
- [x] `Sona.Chats.list_company_users/1` returns members of the company
- [x] `Sona.Chats.subscribe_room/1` subscribes to the room PubSub topic
- [x] Chat context never calls Accounts and never touches `Repo` for cross-company queries
- [x] Context tests covering all of the above, including concurrent `find_or_create_direct_room/2` → one room

## Notes
- 2026-07-10: started implementation — create Sona.Chat context module with all domain functions and tests
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
- 2026-07-10: renamed Sona.Chat → Sona.Chats (plural context convention); added unique index on rooms(company_id, type, name) for concurrency-safe ensure_default_room; fixed direct_token lowercase; constraint-error detection scoped to specific constraint names; Repo.aggregate for membership counts; explicit assert_receive timeout