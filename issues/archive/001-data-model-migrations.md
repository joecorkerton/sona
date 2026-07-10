---
id: 001
title: Data model & migrations
status: done
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
- [x] Migration creates `companies`, `users`, `rooms`, `memberships`, `messages` tables with uuid PKs
- [x] `companies.invite_token` has a unique index
- [x] `users` has a unique index on `(company_id, username)`
- [x] `rooms` has a unique index on `direct_token`
- [x] `memberships` has a unique index on `(room_id, user_id)` and a plain index on `user_id`
- [x] `messages` has an index on `(room_id, inserted_at)` and a self-referential nullable `parent_id` FK
- [x] Ecto schemas with changesets validate: username format/length, company name present, message body present, room name present for `:group`
- [x] Associations defined: `user.company`, `message.user`, `room.company`, `room.memberships`, `membership.room`, `membership.user`
- [x] `users.display_name` has no DB default (set explicitly at insert)
- [x] `users.username` is normalized to lowercase at insert time
- [x] `mix ecto.migrate` succeeds
- [x] Changeset tests: duplicate username in same company fails; same username in two companies succeeds

## Notes
- 2026-07-10: started implementation — generate migration, create Ecto schemas with changesets and associations, write tests
- 2026-07-10: migration created (5 tables, all indexes), schemas with changesets + associations written, 16 tests passing — all acceptance criteria met
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
- 2026-07-10: review fixes — reordered normalize before validate_format in User; removed programmatic FKs (:company_id, :room_id, :user_id, :parent_id) from cast; fixed unique_constraint in Membership (composite field syntax); added Membership test; removed :invite_token from cast in Company; added integration test for mixed-case username insertion