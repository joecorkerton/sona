---
id: 026
title: Wire On Shift room into `SessionController.create` + seeds
status: todo
created: 2026-07-14
depends_on: [024, 025]
---

## Goal
Ensure the On Shift room (with the creator as a manager member) exists immediately after a company is created via `POST /session`, so the manager lands in `/chats` with the On Shift group already visible. Have the demo seeds also push an initial roster to the ingress so the demo shows an on-shift staff member from the start.

## Context
See `plans/on-shift-broadcast-group.md` "SessionController wiring" and "Seeds".

Wiring rules:
- `SessionController.create/2` (company create): after `Accounts.create_company` and `Chats.ensure_default_room`, call `Sona.Shifts.ensure_on_shift_room/1` (passing the company or the manager) so the room + manager membership exist before the manager reaches `/chats`.
- `SessionController.join/2` (staff join): **no** `Sona.Shifts` call — staff join `:staff`, land in General, and enter On Shift only via roster reports. Keeps join fast and keeps the role of "on shift" clear.

Seeds (`priv/repo/seeds.exs`):
- After the existing chat seeds, call `Sona.Shifts.ensure_on_shift_room(company)` (idempotent; ensures the room + alice as manager member even on a fresh reseed).
- Push an initial roster: `Sona.Shifts.Ingress.report(company.id, [bob.id])` — alice is the manager, bob is on shift at seed time. Charlie is added/removed later by the simulator (028) when enabled.
- Print the On Shift room id + initial member count in the seed summary.

The creator's `role: :manager` is set in 022 (`Accounts.create_company/1`); this issue consumes that fact by asserting the On Shift room has the creator as a manager member.

## Acceptance criteria
- [ ] `SonaWeb.SessionController.create/2` calls `Sona.Shifts.ensure_on_shift_room(company)` (or `alice`) after `Accounts.create_company` and `Chats.ensure_default_room`
- [ ] `SonaWeb.SessionController.join/2` does **not** call any `Sona.Shifts` function — a test asserts the On Shift room is unchanged by a join
- [ ] `priv/repo/seeds.exs` calls `Sona.Shifts.ensure_on_shift_room(company)` after the existing chat seeds
- [ ] `priv/repo/seeds.exs` calls `Sona.Shifts.Ingress.report(company.id, [bob.id])` to push the initial roster (alice manager, bob on shift at seed time)
- [ ] The seed summary prints the On Shift room id and the initial member count
- [ ] `test/sona_web/controllers/session_controller_test.exs` (new or extended): `POST /session` with company-create params results in a company with an `:on_shift` room whose memberships include the creator; `POST /join/:token/session` with valid params leaves the On Shift room memberships unchanged
- [ ] `mix precommit` passes for this slice

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("SessionController wiring", "Seeds", "Files to create / touch"). The On Shift room is created during the company-create flow so the manager reaches `/chats` with the group already visible (no "set up your On Shift group" gate). The dev simulator (028) drives further membership changes; without it enabled, the On Shift room holds alice + bob (the seeded roster) statically. Deps: [024, 025].
