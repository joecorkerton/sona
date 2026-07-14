---
id: 028
title: Dev roster simulator `Sona.Shifts.Simulator` + config
status: todo
created: 2026-07-14
depends_on: [025]
---

## Goal
Add a config-gated `Sona.Shifts.Simulator` GenServer that periodically pushes changing roster snapshots to the ingress, so the On Shift group's dynamic membership is observable during development without wiring a real external system. **Off by default**; enabled by `SHIFT_SIMULATOR=1` in dev only.

## Context
See `plans/on-shift-broadcast-group.md` "`Sona.Shifts.Simulator` (dev, config-gated)" and "Config". The simulator is the **fake external system** in this slice; in production it would be replaced by a real staff-scheduling connector calling `Sona.Shifts.Ingress.report/2` directly.

Behavior:
- `:timer.send_interval(interval, :tick)` (stdlib) — **no `Process.sleep`** per `AGENTS.md`.
- On `:tick`: pick a roster for the seeded company from a small deterministic rotation among seeded staff (e.g. `bob` then `charlie` then `[bob, charlie]` then `[]` — chosen via `rem` on a tick counter); call `Sona.Shifts.Ingress.report(company.id, user_ids)`. The plan's open question #3 is resolved to **simple deterministic rotation** for the POC.
- Started from `application.ex` only when `Application.get_env(:sona, :shift_simulator, false) == true`. In test env it is **explicitly off** (`config :sona, :shift_simulator, false`) so tests never get surprise roster ticks.

## Acceptance criteria
- [ ] `lib/sona/shifts/simulator.ex` defines `Sona.Shifts.Simulator` with `use GenServer`; named `__MODULE__`
- [ ] On init, schedules `:tick` via `:timer.send_interval(interval, :tick)` where `interval` is read from `Application.get_env(:sona, :shift_simulator_interval_ms, 60_000)`
- [ ] On `handle_info(:tick, state)`, picks a deterministic roster (a tick counter is enough — e.g. `:ets`/process-dict, or stored in `state`) for the seeded company and calls `Sona.Shifts.Ingress.report(company.id, user_ids)`
- [ ] The roster source is the simple deterministic rotation among seeded staff per the plan's open question #3 default (no `Sona.Guide.ShiftData` derivation in this slice)
- [ ] `lib/sona/application.ex` adds `{Sona.Shifts.Simulator, []}` to the children list **only when** `Application.get_env(:sona, :shift_simulator, false)` is truthy (e.g. via a conditional that builds the child spec list)
- [ ] `config/dev.exs` adds `config :sona, :shift_simulator, System.get_env("SHIFT_SIMULATOR") == "1"` and `config :sona, :shift_simulator_interval_ms, 60_000` (off by default)
- [ ] `config/test.exs` sets `config :sona, :shift_simulator, false` (explicit; the default is already false but be explicit so a `mix test` never gets surprise roster ticks)
- [ ] `test/sona/shifts/simulator_test.exs` (new) — the simulator is **not** started when config is false (asserted by inspecting `Supervisor.which_children/1` of `Sona.Supervisor`, or by starting the app with config false and asserting no `Sona.Shifts.Simulator` pid exists); a `:tick` sends a `report/2` to the ingress (stub `Ingress` with a test process or assert on the resulting membership state via `Sona.Shifts.list_on_shift_user_ids/1`); no `Process.sleep` per `AGENTS.md` — use `Process.monitor/1` + `assert_receive {:DOWN, ...}` for teardown and `_ = :sys.get_state/1` to sync
- [ ] `mix precommit` passes for this slice

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("`Sona.Shifts.Simulator` (dev, config-gated)", "Config", "Tests", "Files to create / touch"). The simulator is the **fake external system** — a real staff-scheduling connector is a later plan and would call `Sona.Shifts.Ingress.report/2` directly. Open question #3 resolved to **simple deterministic rotation** for the POC (per the plan's default). Deps: [025] (Ingress is the only required seam; the simulator does not need the SessionController wiring from 026 or the LiveView changes from 027).
