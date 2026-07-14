---
id: 022
title: Add `users.role` column + Accounts role wiring
status: todo
created: 2026-07-14
depends_on: []
---

## Goal
Introduce a `role` field on `users` (`:manager` / `:staff`) so the company creator can be designated a manager durably, and joiners default to staff. The role is set programmatically (per `AGENTS.md`) — it must **not** be castable from user attrs.

## Context
See `plans/on-shift-broadcast-group.md` "Decisions confirmed with the user" (decision #1: manager designation via a `role` column), "Data model changes" (the `users.role` column + schema field), and "Accounts changes" (creator `:manager`, joiner `:staff`).

This is the foundation for the On Shift group's "managers are always members" reconciliation rule (`Sona.Shifts.reconcile_on_shift/2` in 024). It is the durable source of truth for the manager flag and is set **once** at user creation time; there is no UI to promote/demote in this slice (deferred per the plan's "Out of scope").

## Acceptance criteria
- [ ] Migration `mix ecto.gen.migration add_role_to_users` adds `add :role, :string, null: false, default: "staff"` to `users`; existing rows backfilled to `"staff"` by the default; `mix ecto.migrate` succeeds
- [ ] `User` schema gains `field :role, Ecto.Enum, values: [:manager, :staff], default: :staff`
- [ ] `User.changeset/2` does **not** include `:role` in its `cast` allow-list (programmatically-set field per `AGENTS.md`); changesetting `%{role: :manager}` attrs on a joiner does not promote them — asserted by test
- [ ] `Accounts.create_company/1` sets the creator's `role: :manager` on the struct before insert (i.e. `Ecto.Changeset.change(creator, role: :manager)` after the `User.changeset/2` step, or pass it directly on the `%User{...}` struct — the result is a manager row regardless of any attrs the caller provides)
- [ ] `Accounts.get_or_create_user/2` joiners default to `:staff` (column default covers it; a test asserts a new joiner's `role == :staff`)
- [ ] `test/sona/accounts_test.exs` extended with: creator of `create_company` has `role: :manager`; `get_or_create_user/2` returns `:staff` for a fresh joiner; `role` is not settable via `User.changeset/2` attrs
- [ ] `mix precommit` passes for this slice (compile, format, credo --strict, test)

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("Decisions confirmed with the user" #1, "Data model changes", "Accounts changes", "Migrations"). Foundation for 024's reconciliation rule ("never remove a manager from On Shift"). No deps.
