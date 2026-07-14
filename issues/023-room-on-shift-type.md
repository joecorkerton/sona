---
id: 023
title: Extend `Room.type` with `:on_shift` + guard `Chats.create_group_room`
status: todo
created: 2026-07-14
depends_on: []
---

## Goal
Extend the `rooms.type` Ecto.Enum with the new `:on_shift` value (code-only — no DB migration, since the column is `:string`) and guard `Chats.create_group_room/3` so it can never produce an `:on_shift` row. `Sona.Shifts.ensure_on_shift_room/1` (issue 024) is the only path that creates `:on_shift` rooms.

## Context
See `plans/on-shift-broadcast-group.md` "Data model changes" (the `:on_shift` room type) and "Chats changes (minimal)" (extending the `Ecto.Enum`; keeping `create_group_room/3` hard-coded to `:group`).

Key invariants:
- The `rooms.type` column is `:string` (matching the existing `:direct`/`:group` pattern); adding `:on_shift` to the schema's `Ecto.Enum` is **a code change only — no DB migration** for the value itself.
- The existing `unique_index(:rooms, [:company_id, :type, :name])` gives us one `:on_shift` room per company when paired with a fixed non-null name `"On Shift"`. NULL `name`s would collide across the type — we use a non-null fixed name to avoid that edge case.
- `Chats.create_group_room/3` is the user-facing path for user-created group rooms; it must stay `:group` only. The test asserts that a caller cannot coerce the type to `:on_shift` via attrs (the type comes from the function, not attrs, so it's already safe — assert it).

## Acceptance criteria
- [ ] `Room` schema: `field :type, Ecto.Enum, values: [:direct, :group, :on_shift]`
- [ ] `validate_room_name/1` (or equivalent changeset validation in `Room.changeset/2`) requires `:name` for `:on_shift` rooms in addition to `:group` rooms (a direct room with no name is still valid)
- [ ] `Chats.create_group_room/3` still hard-codes `type: :group`; a test asserts that no attrs combination can produce an `:on_shift` row through it
- [ ] No new DB migration for the `:on_shift` enum value (column is `:string`)
- [ ] `test/sona/chats_test.exs` extended with: the `:on_shift` guard assertion on `create_group_room/3`; `Room.changeset/2` accepts a `:on_shift` room with a `name` and rejects one without
- [ ] `mix precommit` passes for this slice

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("Data model changes", "Changes", "Migrations"). The "No migration for the `:on_shift` room type value" guarantee is recorded as an acceptance criterion (mirrors the plan's "no DB migration" requirement). Deps: [].
