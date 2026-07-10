---
id: 001
title: Data model & migrations
status: todo
created: 2026-07-10
depends_on: []
---

## Goal
Durable Postgres schema for companies, users, rooms, memberships, and messages that supports company-scoped chat with DM uniqueness and a hook for future threads.

## Context
Foundation chunk everything else depends on. See `plans/basic-chat-poc.md` sections "Data model" (lines 96–161) and "Chunk 1" (lines 282–291).

Key data model:
- `companies`: id (uuid), name (string not null), invite_token (string not null unique), timestamps.
- `users`: id (uuid), company_id FK, username (string not null, normalized lowercase), display_name (string optional, no DB default — set at insert), timestamps, unique index on `(company_id, username)`.
- `rooms`: id (uuid), company_id FK, `type` as `Ecto.Enum` `[:direct, :group]` (not DB enum), name (string nullable — required for group, null for direct), `direct_token` (string nullable unique — `"direct:<lo>|<hi>"` sorted-lowercased user-id pair, null for group), timestamps.
- `memberships`: id (uuid), room_id FK, user_id FK, timestamps, unique `(room_id, user_id)`, index on `user_id` (for `list_rooms_for_user/1`). App-enforced invariants: `user.company_id == room.company_id`; `:direct` rooms have exactly two memberships; `:group` >= 1.
- `messages`: id (uuid), room_id FK, user_id FK (author), body (text not null), parent_id (uuid FK messages nullable — unused in UI, future threads), timestamps, index `(room_id, inserted_at)`.

Reuse commit SHA: schema files list at `plans/basic-chat-poc.md#data-model`.

## Acceptance criteria
- [ ] Migration creates `companies`, `users`, `rooms`, `memberships`, `messages` tables with uuid PKs
- [ ] `companies.invite_token` has a unique index
- [ ] `users` has a unique index on `(company_id, username)`
- [ ] `rooms` has a unique index on `direct_token`
- [ ] `memberships` has a unique index on `(room_id, user_id)` and a plain index on `user_id`
- [ ] `messages` has an index on `(room_id, inserted_at)` and a self-referential nullable `parent_id` FK
- [ ] Ecto schemas with changesets validate: username format/length, company name present, message body present, room name present for `:group`
- [ ] Associations defined: `user.company`, `message.user`, `room.company`, `room.memberships`, `membership.room`, `membership.user`
- [ ] `users.display_name` has no DB default (set explicitly at insert)
- [ ] `users.username` is normalized to lowercase at insert time
- [ ] `mix ecto.migrate` succeeds
- [ ] Changeset tests: duplicate username in same company fails; same username in two companies succeeds