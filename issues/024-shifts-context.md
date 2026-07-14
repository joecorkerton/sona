---
id: 024
title: `Sona.Shifts` context — On Shift room + reconciliation
status: todo
created: 2026-07-14
depends_on: [022, 023]
---

## Goal
Build the `Sona.Shifts` context: it owns the per-company `:on_shift` room and reconciles its non-manager membership to a roster snapshot, while keeping all `:manager` users as permanent members. It is the public domain API the `Ingress` (025), `SessionController` (026), `InboxLive`/`RoomLive` (027), and `Simulator` (028) all call into.

## Context
See `plans/on-shift-broadcast-group.md` "`Sona.Shifts` context public API", "Layering", and "Data model changes". Depends on the `role` column from 022 (to identify managers) and the `:on_shift` enum value from 023 (to type the room).

Layering invariant (call out in `@moduledoc`):
- `Sona.Shifts` depends only on `Sona.Accounts` (`%User{}`, `%Company{}`) and `Sona.Repo`. It does **not** call `Sona.Chats` for message sending — managers send through the existing `Sona.Chats.send_message/3` against the On Shift `%Room{}`. `Sona.Shifts` does, however, manage `Membership` rows for the On Shift room (it owns those memberships; this overlaps `Sona.Chats`'s membership ownership **only** for the special room, which is acceptable — `Sona.Chats` remains the owner for all other rooms).
- All APIs are company-scoped; every lookup filters by `company_id`.

Reconciliation rule (the core):
1. Fetch the On Shift room (creating it via `ensure_on_shift_room/1` if missing).
2. Ensure **all** company managers (`role: :manager`) are members (add missing; never remove here).
3. Compute target non-manager memberships = the given `on_shift_user_ids` ∩ users whose `company_id == company_id` (defensive: rejects any id not in the company silently).
4. Current non-manager members = `memberships` on the room whose user `role != :manager`.
5. **Remove** current non-manager members whose user_id ∉ target.
6. **Add** target user_ids not already members.
7. Return `{:ok, %{added: [...], removed: [...], room: %Room{}}}` (the diff is useful for tests and an optional future broadcast).

## Acceptance criteria
- [ ] `lib/sona/shifts.ex` defines `Sona.Shifts` with the five public functions from the plan: `ensure_on_shift_room/1`, `reconcile_on_shift/2`, `list_on_shift_members/1`, `list_on_shift_user_ids/1`, `manager?/1`
- [ ] `@moduledoc` documents the layering: depends only on `Sona.Accounts` and `Sona.Repo`; does not call `Sona.Chats` for sending; owns On Shift room memberships (overlap with `Sona.Chats` only for this special room)
- [ ] `ensure_on_shift_room/1` accepts `%Company{}` or `%User{}`; idempotent — rescues the `rooms_company_id_type_name_index` unique violation and re-fetches the existing row; on create, adds **all current company managers** as members
- [ ] `ensure_on_shift_room/1` is safe under concurrent callers (the rescue + re-fetch handles the race per the same pattern as `Chats.ensure_default_room`)
- [ ] `reconcile_on_shift(company_id, on_shift_user_ids)` runs the six steps above in **one `Repo.transaction`**; returns `{:ok, %{added: [user_id, ...], removed: [user_id, ...], room: %Room{}}}`
- [ ] `reconcile_on_shift/2` rejects user ids from other companies silently (intersection with the company's users)
- [ ] `reconcile_on_shift/2` short-circuits when the target set equals the current non-manager member set — no writes occur (roster stability, per the plan's open question #4)
- [ ] `list_on_shift_members(room_or_company)` preloads `memberships: [:user]` and returns the users (managers + on-shift staff) — usable by the room header in 027
- [ ] `list_on_shift_user_ids(company_id)` returns the non-manager member user ids of the On Shift room
- [ ] `manager?(%User{})` returns `user.role == :manager` (predicate ends in `?` per `AGENTS.md`)
- [ ] `test/sona/shifts_test.exs` (new, `Sona.DataCase`) covers: idempotent `ensure_on_shift_room/1` under concurrent calls; managers stay members across reconciles; `[bob]` adds bob and keeps managers; a follow-up reconcile to `[charlie]` removes bob and adds charlie; a follow-up to `[]` removes charlie and leaves only managers; cross-company user ids are silently ignored (no error, no membership changes for them); diff return shape matches `%{added: [...], removed: [...], room: %Room{}}`; the no-op short-circuit
- [ ] `mix precommit` passes for this slice

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("`Sona.Shifts` context public API", "Layering", "Tests"). The core domain module; everything else (025 Ingress, 026 SessionController, 027 Inbox/Room, 028 Simulator) calls into it. Deps: [022, 023].
