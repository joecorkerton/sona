---
id: 025
title: `Sona.Shifts.Ingress` GenServer + supervisor wiring
status: todo
created: 2026-07-14
depends_on: [024]
---

## Goal
Add the single named GenServer `Sona.Shifts.Ingress` that exposes a public Elixir API `report(company_id, user_ids)` and forwards to `Sona.Shifts.reconcile_on_shift/2`. One named process serializes all reconciliations so roster-vs-roster races are impossible without ad-hoc locking. Wire it into the app supervisor.

## Context
See `plans/on-shift-broadcast-group.md` "`Sona.Shifts.Ingress` GenServer" and "Layering". The ingress is the **single integration seam** — a future real external staff-scheduling system would replace the dev simulator (028) by pushing events into this same GenServer.

Per `AGENTS.md` OTP rule, the GenServer is registered with a name (`name: __MODULE__`). It owns no durable state beyond an optional in-memory `last_roster` cache (harmless; not load-bearing — a restart simply applies the next report). The app supervisor (`Sona.Supervisor` in `application.ex`) starts it as a sibling of `Sona.Repo`, `Sona.PubSub`, and `SonaWeb.Endpoint`.

## Acceptance criteria
- [ ] `lib/sona/shifts/ingress.ex` defines `Sona.Shifts.Ingress` with `use GenServer`
- [ ] Public API `Sona.Shifts.Ingress.report(company_id, user_ids)` is a `GenServer.call(__MODULE__, {:report, company_id, user_ids})`
- [ ] `start_link/1` returns `GenServer.start_link(__MODULE__, %{}, name: __MODULE__)` (named registration per `AGENTS.md`)
- [ ] `handle_call({:report, company_id, user_ids}, _from, state)` calls `Sona.Shifts.reconcile_on_shift(company_id, user_ids)` and replies with `{:reply, result, state}` where `result` is `{:ok, %{added: _, removed: _, room: _}} | {:error, reason}`
- [ ] `lib/sona/application.ex` adds `{Sona.Shifts.Ingress, []}` to the `children` list (so the process is started with the rest of the app under `Sona.Supervisor`)
- [ ] `test/sona/shifts/ingress_test.exs` (new): starts the GenServer under `start_supervised!` (with a name per `AGENTS.md`); two consecutive `report/2` calls converge to the latest roster; an empty roster leaves only managers; the GenServer serializes concurrent `report/2` calls (asserted by the determinism of the final state, no extra locking)
- [ ] `mix precommit` passes for this slice

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("`Sona.Shifts.Ingress` GenServer", "Layering", "Files to create / touch", "Tests"). This is the single integration seam; a real external connector would call `Sona.Shifts.Ingress.report/2` instead of using the dev simulator (028). Deps: [024].
