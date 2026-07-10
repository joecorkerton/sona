---
id: 003
title: Chat context (rooms, membership, messages, DMs)
status: todo
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
- [ ] `Sona.Chat.ensure_default_room/2` creates a "General" `:group` room + creator membership; idempotent
- [ ] `Sona.Chat.add_to_general/1` adds the user as a member of the company's General room
- [ ] `Sona.Chat.create_group_room/2` creates a `:group` room with `company_id` and creator membership (creator is sole member)
- [ ] `Sona.Chat.list_rooms_for_user/1` returns the user's rooms (company-implied); does not cross companies
- [ ] `Sona.Chat.list_messages/2` returns last N messages oldest→newest
- [ ] `Sona.Chat.send_message/3` checks membership + same-company and broadcasts `{:new_message, msg}` to the room PubSub topic
- [ ] `Sona.Chat.send_message/3` rejects non-members and cross-company users
- [ ] `Sona.Chat.find_or_create_direct_room/2` rejects self-DM with `{:error, :self}`
- [ ] `Sona.Chat.find_or_create_direct_room/2` rejects cross-company with `{:error, :cross_company}`
- [ ] A↔B and B↔A resolve to the same room (canonical `direct_token`)
- [ ] Concurrent `find_or_create_direct_room/2` (two tasks) yields one room (rescues `Ecto.ConstraintError` and re-fetches)
- [ ] `Sona.Chat.list_company_users/1` returns members of the company
- [ ] `Sona.Chat.subscribe_room/1` subscribes to the room PubSub topic
- [ ] Chat context never calls Accounts and never touches `Repo` for cross-company queries
- [ ] Context tests covering all of the above, including concurrent `get_or_create_user/2` same username → one user