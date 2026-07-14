# Plan: On-Shift Broadcast Group

**In-repo copy:** [`plans/on-shift-broadcast-group.md`](on-shift-broadcast-group.md)
(canonical for the project; keep in sync when revising).

## Context

Sona is a hospitality communications POC (see `README.md`, `docs/task-info.md`,
`plans/basic-chat-poc.md`, `plans/ai-shift-guide.md`). The basic chat spine
(1-1 + group, company-scoped, mobile-first LiveView, PubSub, streams) is in
place: `lib/sona/chats.ex`, `lib/sona_web/live/{inbox,room}_live.ex`, seeds,
tests. Users belong to a company; usernames are unique per company; onboarding
is by company invite link. There are **no roles** today (deferred in
`basic-chat-poc.md`) and **no persisted shift data** — shift/overtime/demand
data only exists as hardcoded functions in `Sona.Guide.ShiftData`, used solely
to build the AI guide prompt.

Hospitality managers want to reach the staff who are **currently on shift**
with one message ("the walk-in freezer alarm is going off", "we need hands at
the front desk now"). The set of people on shift changes through the day, so
the audience has to be dynamic — a static group that the manager edits each
time is too much friction.

This plan adds a single **per-company "On Shift" group** whose membership is
driven by external shift updates. Managers are permanently members (so they
can always post and watch the channel); on-shift staff are added and removed
automatically as shift updates arrive. A message sent to the On Shift group
reaches exactly the current on-shift staff (plus the managers), using the
existing `Chats.send_message/3` + `chat:room:<id>` PubSub machinery unchanged.

The **integration boundary** is a **fake websocket / event endpoint** modelled
as a GenServer (`Sona.Shifts.Ingress`) with a public Elixir API. In production
this seam would be a real websocket/stream from an external staff-scheduling
system; here it is a named GenServer that receives roster snapshots. A small
dev-only **roster simulator** (`Sona.Shifts.Simulator`, config-gated) feeds
the ingress on an interval so the dynamic membership changing over time can be
seen without wiring a real external system.

### Decisions confirmed with the user

1. **Manager designation:** add a `role` field to `users` (`:manager` /
   `:staff`). Company creator becomes `:manager`; joiners are `:staff`. This is
   the durable source of truth for "never remove a manager from On Shift" and
   lets the reconciliation rule be enforced in one place.
2. **Ingress shape:** a **GenServer API only** — `Sona.Shifts.Ingress` with a
   public Elixir `report/2` function. No HTTP surface, no Phoenix channel in
   this slice; events are pushed from Elixir (the seed simulator / `iex` / a
   future real connector). The GenServer is the single ingress seam.
3. **Event granularity:** **roster snapshot replace.** Each report carries the
   *full* current on-shift roster for a company; the app replaces the whole
   On Shift membership (minus managers) to match. Robust to dropped events and
   trivially idempotent.

---

## Goals

### In scope (this slice)

- A **per-company "On Shift" group** room (`:on_shift` type) that exists for
  every company.
- **Managers (`role: :manager`) are always members** of their company's On
  Shift group; staff (`:staff`) are members **only while their user id is in
  the latest roster snapshot**.
- A **`Sona.Shifts.Ingress` GenServer** (the fake event endpoint) that receives
  roster snapshots via `report(company_id, user_ids)` and reconciles the On
  Shift membership through a new `Sona.Shifts` context.
- A manager can **post a message to the On Shift group** that reaches the
  current on-shift staff in realtime (existing `send_message`/PubSub).
- A config-gated **dev roster simulator** that pushes changing rosters to the
  ingress on an interval so dynamic membership is observable.
- The On Shift group appears in the manager's chat list (and in an on-shift
  staff member's list while they are on shift).
- Public context/ingress functions tested; LiveView flows covered with
  element assertions; `mix precommit` green.

### Out of scope (later plans)

- A **real external websocket/HTTP connector** to an actual staff-scheduling
  system. The ingress GenServer is the seam; a real connector is a later task.
- **Persisted shift data** (`shifts`, `shift_assignments` tables). Roster state
  lives in the On Shift *membership* (which is persisted) plus the optional
  simulator's in-memory bookkeeping. On server restart, the next roster
  snapshot self-corrects membership; we do not durably store "who is on
  shift" beyond the membership itself.
- **Historical member roster** per message ("who exactly received this
  broadcast at send time"). Messages persist in the room; past members lose
  access when removed. A read receipt / delivery log is a later plan.
- Roles UI (promoting/demoting users). The `role` column is seeded/created
  via the existing flows; an admin UI for it is later.
- Authentication on the ingress (any caller can `report/2`). A real connector
  would carry credentials; out of scope.
- Non-manager staff **posting** to the On Shift group. They *receive*; only the
  question of whether they can post is deferred — see Open questions.
- Onboarding UI explaining the role/On Shift concept.

---

## Product / user flows

### A. Company creation seeds the manager + On Shift group

1. First user creates a company (`/` → `POST /session`). They are created with
   `role: :manager`. The controller (in addition to `General`) **ensures the
   On Shift group** via `Sona.Shifts.ensure_on_shift_room/1`, with the manager
   as an initial member.
2. The manager lands in `/chats`; the On Shift group appears in their chat
   list, distinct from other rooms (dedicated icon/"On Shift" label).

### B. Staff join the company, are not on shift yet

1. Staff join via the invite link (`/join/:token` → `POST /join/:token/session`).
   They are created with `role: :staff`. They land in `General`.
2. Until a roster report includes them, they are **not** members of the On
   Shift group; it does not appear in their chat list.

### C. Shift updates arrive → On Shift membership changes

1. The external (here: simulated) system pushes a **roster snapshot** to the
   ingress: `Sona.Shifts.Ingress.report(company_id, [bob_id, charlie_id])`.
2. The ingress forwards to `Sona.Shifts.reconcile_on_shift/2`, which sets the
   On Shift group's non-manager membership to exactly `[bob, charlie]`:
   - adds bob & charlie as members (idempotent),
   - removes any on-shift staff no longer in the roster (idempotent),
   - **never touches manager memberships** (managers are always present;
     `reconcile_on_shift/2` ensures all company managers are members at the
     start of every reconcile).
3. A subsequent `report(company_id, [charlie_id])` removes bob, keeps charlie.
   An empty roster `report(company_id, [])` leaves only the managers.
4. With the dev simulator enabled, this is driven automatically on an
   interval so membership visibly changes over time.

### D. Manager broadcasts to everyone on shift

1. Manager opens the On Shift group (`/chats/<on_shift_room_id>`), sees the
   current roster (member list / count in the header) and any prior messages.
2. Manager types and sends. `Chats.send_message/3` (unchanged) persists the
   message and broadcasts `{:new_message, msg}` to `chat:room:<id>`. Every
   current member (managers + on-shift staff) with the room open, or later
   listing the room, receives it.
3. As the roster changes, future posts reach exactly whoever is on shift at
   send time — no group re-creation needed.

### E. On-shift staff see the broadcast

1. While on shift, the On Shift group appears in an on-shift staff member's
   chat list; they can open it and read/send. If they come on shift *after* a
   message was sent, they see the room history on open (joining a group shows
   persisted messages — same as General).
2. When their shift ends and the roster no longer lists them, they are removed
   from the group; it disappears from their chat list and they can no longer
   open the room (`RoomLive` membership check denies access).

---

## Architecture / design

### Layering

```
┌──────────────────────────────────────────────────────┐
│  External (future) staff scheduler ── (fake here) ── │
│        Sona.Shifts.Simulator (dev, config-gated)     │
└──────────────────────────────────────────────────────┘
                       │ report(company_id, user_ids)
                       ▼
┌──────────────────────────────────────────────────────┐
│  Sona.Shifts.Ingress  (GenServer — the seam)         │
│  public API: report/2; serializes per reconcile      │
└──────────────────────────────────────────────────────┘
                       │ Sona.Shifts.reconcile_on_shift/2
                       ▼
┌──────────────────────────────────────────────────────┐
│  Sona.Shifts context  (owns On Shift room + roster)   │
│  ensure_on_shift_room/1 · list_on_shift_members/1    │
│  reconcile_on_shift/2 · list_on_shift_user_ids/1     │
└──────────────────────────────────────────────────────┘
                       │ memberships on the :on_shift room
                       ▼
┌──────────────────────────────────────────────────────┐
│  Existing chat spine (unchanged)                     │
│  Sona.Chats.send_message/3 · PubSub "chat:room:<id>" │
│  InboxLive / RoomLive                                  │
└──────────────────────────────────────────────────────┘
```

- **New context `Sona.Shifts`** owns the On Shift room + roster/membership
  reconciliation. It depends only on `Sona.Accounts` (`%User{}`, `%Company{}`)
  and `Sona.Repo`. **It does not call `Sona.Chats`** directly for message
  sending — managers send through the existing `Sona.Chats.send_message/3`
  against the On Shift `%Room{}`. `Sona.Shifts` does, however, manage
  `Membership` rows for the On Shift room (it owns those memberships; this
  overlaps `Sona.Chats`'s membership ownership only for the special room, which
  is acceptable — `Sona.Chats` remains the owner for all other rooms). Document
  this boundary in module docs.
- **`Sona.Shifts.Ingress` GenServer** is the single named ingress point. It
  serializes reconciliations (one process) and owns no durable state beyond an
  optional cached last-roster (in-memory; snapshots are idempotent so a restart
  just waits for the next report). Registered as `Sona.Shifts.Ingress`.
- **`Sona.Shifts.Simulator`** (dev-only, started only when
  `Application.get_env(:sona, :shift_simulator, false)`) is the fake external
  system. On an interval (config: `:shift_simulator_interval_ms`, default
  e.g. 60000) it computes a roster from `Sona.Guide.ShiftData` upcoming shifts
  (or a simple deterministic rotation among the seeded staff) and calls
  `Sona.Shifts.Ingress.report/2`. It exists to demonstrate "membership changing
  over time" without a real external feed.
- All data stays company-scoped; every `Sona.Shifts` API filters by
  `company_id`. The On Shift room is created per company.

### Data model changes

New column on `users`:

```
users
  + role    string not null default 'staff'   -- :manager | :staff (Ecto.Enum)
```

- Add via migration `mix ecto.gen.migration add_role_to_users`: `add :role,
  :string, null: false, default: "staff"`. Backfill existing rows (default on
  the column covers them). Use **plain `:string`** (consistent with the
  existing `rooms.type` pattern), not a DB enum, so extending later is easy.
- Schema: `field :role, Ecto.Enum, values: [:manager, :staff], default: :staff`.
- `Accounts.create_company/1` sets the creator `role: :manager` (set
  explicitly on the struct before insert, **not** via `cast` — per AGENTS.md
  programmatically-set fields must not be in `cast`). `get_or_create_user/2`
  joins as `:staff` (the column default handles it; nothing to set).

No new tables. The On Shift room is just a `rooms` row with a new type value:

```
rooms.type  Ecto.Enum values: [:direct, :group, :on_shift]   -- add :on_shift
```

- The migration column is `:string` (not a DB enum), so adding `:on_shift` to
  the schema's `Ecto.Enum` values is **a code change only — no DB migration**
  for the enum value.
- The existing unique index `rooms(company_id, type, name)` lets us have one
  `:on_shift` room per company when paired with a fixed name `"On Shift"`
  (NULL names collide elsewhere; we use a non-null fixed name).

### `Sona.Shifts` context public API

- `ensure_on_shift_room(%Company{} | %User{}) :: {:ok, %Room{}}` — idempotent
  get-or-create the company's `:on_shift` room named `"On Shift"`. On create,
  adds **all current company managers** as members (so they are present before
  any roster report). Rescue the `rooms_company_id_type_name_index` unique
  constraint and re-fetch (same pattern as `ensure_default_room`). Used by the
  `SessionController` create flow.
- `reconcile_on_shift(company_id, on_shift_user_ids)` — the core. Steps,
  in one `Repo.transaction`:
  1. Fetch the On Shift room (creating it via `ensure_on_shift_room/1` if
     missing).
  2. Ensure **all** company managers (`role: :manager`) are members (add
     missing; never remove here).
  3. Compute target non-manager memberships = the given `on_shift_user_ids`
     ∩ users whose `company_id == company_id` (defensive; rejects any id not
     in the company silently).
  4. Current non-manager members = `memberships` on the room whose user
     `role != :manager`.
  5. **Remove** current non-manager members whose user_id ∉ target.
  6. **Add** target user_ids not already members.
  7. Return `{:ok, %{added: [...], removed: [...], room: room}}` (the diff is
     useful for tests + an optional broadcast).
- `list_on_shift_members(room_or_company)` — preloads `memberships: [:user]`,
  returns users (managers + on-shift staff) — used by Header/member count.
- `list_on_shift_user_ids(company_id)` — current non-manager member user ids
  (the inverse of reconcile; lets the simulator read state and lets tests
  assert). Optional convenience.
- `manager?(%User{})` — `user.role == :manager` (thin helper, used by reconcile
  guard and UI). Predicate ends in `?` per AGENTS.md.

### `Sona.Shifts.Ingress` GenServer

```elixir
defmodule Sona.Shifts.Ingress do
  use GenServer
  # public API
  def report(company_id, user_ids), do: GenServer.call(__MODULE__, {:report, company_id, user_ids})
  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  # handle_call({:report, company_id, user_ids}, ...) -> Sona.Shifts.reconcile_on_shift/2
end
```

- Single named process → serializes all reconciliations (avoids
  roster-vs-roster races without ad-hoc locking). Roster-snapshot-replace is
  already idempotent and convergent, so a crash-then-restart simply applies the
  next report.
- Registered under `Sona.Supervisor` in `application.ex` (give a name per
  AGENTS.md OTP rule). The ingress keeps no durable state; an optional
  in-memory `last_roster` copy keyed by `company_id` is harmless and useful
  for `iex` introspection, but not load-bearing.

### `Sona.Shifts.Simulator` (dev, config-gated)

```elixir
# started in application.ex only when Application.get_env(:sona, :shift_simulator, false)
```

- `:timer.send_interval(interval, :tick)` (stdlib) — no `Process.sleep`.
- On `:tick`: pick a roster for the seeded company from a small deterministic
  schedule (e.g. rotate `bob` then `charlie` then `bob+charlie` then `[]`) or
  derive from `Sona.Guide.ShiftData` upcoming shifts whose `date`/"in progress"
  heuristic matches `Date.utc_today()`; call `Sona.Shifts.Ingress.report/2`.
- Purely a demo aid; off by default. Documented in `config/dev.exs` as an opt-in.

### Routes / LiveView

- **No new route.** The On Shift group is a normal room at `/chats/<id>`;
  `RoomLive` already serves it. We only extend the inbox/room display to
  recognize `:on_shift`.
- `InboxLive`: `room_display_name/2` gains a `:on_shift` clause → `"On Shift"`.
  Only members see it (managers always; staff while on shift) because
  `list_rooms_for_user/1` is membership-backed. Optional: a small "On Shift"
  badge / `hero-bolt` icon so it reads as managed, not a user-created group —
  concrete tokens deferred to the 010–014 styling pass.
- `RoomLive`: `get_header_name` gains a `:on_shift` clause → `"On Shift"`.
  Header could show a live member count (`badge`) when the room is `:on_shift`
  — optional polish; the roster is in the room memberships preload already.

### Realtime contract

- Sending: **unchanged** — `Chats.send_message/3` persists + broadcasts
  `{:new_message, msg}` to `chat:room:<id>`. Manager (and on-shift staff) with
  the room open insert once via the existing single-insert rule. No new PubSub
  topic.
- Roster changes (optional polish): on reconcile, broadcast
  `{:on_shift_roster, member_count}` on a company topic
  `shifts:company:<company_id>`; an open `InboxLive`/`RoomLive` for that
  company can refresh the On Shift row's count. This is a nice-to-have — mark
  optional. If skipped, the chat list/room header reflect membership only on
  the next render/navigation (acceptable for the POC).

---

## Implementation notes

### Migrations

- `mix ecto.gen.migration add_role_to_users` → `add :role, :string, null:
  false, default: "staff"`. Existing rows backfilled to `"staff"` by the
  default; the seeded alice becomes `:manager` via a `Repo.update!` in
  `seeds.exs` (or via `Accounts.create_company` setting the creator, then
  re-seeding — seeds recreate the company from scratch each run, so the
  creator path already promotes alice).
- **No migration for the `:on_shift` room type value** — column is `:string`.
  Just extend the schema's `Ecto.Enum`.

### Accounts changes

- `User` schema: add `field :role, Ecto.Enum, values: [:manager, :staff],
  default: :staff`. Keep it **out of** the `cast` allow-list in
  `User.changeset/2` (it is set programmatically per AGENTS.md).
- `Accounts.create_company/1`: when building the creator `%User{}`, set
  `role: :manager`. Because `role` is not in `cast`, set it via the struct
  before insert (e.g. `%User{company_id: company.id, role: :manager}`) —
  `changeset/2` must not strip it (it isn't in `cast`, so it stays). Verify the
  changeset preserves a pre-set `:role` (it will, since `cast` won't touch it);
  add a test.
- `get_or_create_user/2`: unchanged — new staff default to `:staff` via the
  column default.

### Chats changes (minimal)

- `Room` schema: `field :type, Ecto.Enum, values: [:direct, :group, :on_shift]`.
  `validate_room_name/1` currently requires `:name` for `:group`; extend to
  require `:name` for `:on_shift` too (we always set "On Shift"), or restrict
  to `[:group, :on_shift]`.
- `Chats.create_group_room/3`: **must stay `:group`** — it must never create an
  `:on_shift` room (that path is owned by `Sona.Shifts.ensure_on_shift_room/1`).
  No change needed beyond ensuring it still hard-codes `:group` (it does),
  but add a test that a user cannot create an `:on_shift` room via
  `create_group_room` (the `type` comes from the function, not attrs, so it's
  already safe; assert it).
- `Chats.find_or_create_direct_room/2` and `list_rooms_for_user/1`: unaffected
  (they're typed to `:direct`/membership respectively).

### SessionController wiring

- `SessionController.create/2` (company create): after `Accounts.create_company`
  and `Chats.ensure_default_room`, call `Sona.Shifts.ensure_on_shift_room/1`
  (company, or alice) so the On Shift room + manager membership exist before the
  manager reaches `/chats`.
- `SessionController.join/2` (staff join): **no** shift action — staff join
  `:staff`, land in General; they enter On Shift only via roster reports. (So
  no On Shift call here — keeps join fast and the role of "on shift" clear.)

### Seeds

- After existing chat seeds, add `Sona.Shifts.ensure_on_shift_room/1` for the
  demo company (idempotent; ensures the room + alice as manager member even on
  a fresh reseed).
- Push an initial roster to the ingress so the demo shows on-shift staff
  immediately: `Sona.Shifts.Ingress.report(company.id, [bob.id])` — e.g. bob is
  on shift at seed time. (Charlie added/removed later by the simulator.)
- Mark alice's role as `:manager` — the `create_company` creator path already
  does this; just assert in seed output. (Bob/charlie default `:staff`.)
- Print the On Shift room + initial roster in the seed summary.

### Config

- `config/dev.exs`: add opt-in simulator envs —
  `config :sona, :shift_simulator, System.get_env("SHIFT_SIMULATOR") == "1"`
  and `:shift_simulator_interval_ms` default. Off by default so `mix phx.server`
  doesn't churn memberships unless the dev asks.
- `config/test.exs`: ensure simulator **off** (`config :sona, :shift_simulator,
  false`) so tests never get surprise roster ticks. (Default `false` already
  covers it, but be explicit.)

### Tests

- `test/sona/accounts_test.exs`: creator of `create_company` is `:manager`;
  `get_or_create_user` joins `:staff`; `role` is not cast from attrs (can't set
  `role: :manager` via `User.changeset`).
- `test/sona/shifts_test.exs` (new DataCase): `ensure_on_shift_room/1` creates
  one `:on_shift` room per company (idempotent; concurrent → one); managers are
  members and stay members across reconciles; `reconcile_on_shift/2` with roster
  `[bob]` adds bob and keeps managers; with `[]` removes bob, managers remain;
  rejects user ids from other companies (silently ignored); diff return shape.
- `test/sona/shifts/ingress_test.exs` (new): `Ingress.report/2` drives
  `reconcile_on_shift` (start under `start_supervised!` with a name per
  AGENTS.md); two consecutive reports converge to the latest roster; an empty
  roster leaves only managers.
- `test/sona/chats_test.exs`: assert user cannot create an `:on_shift` room via
  `create_group_room` (type stays `:group`); On Shift room works for
  `send_message` for managers; a staff member not on shift gets
  `{:error, :not_member}` from `send_message` against the On Shift room.
- LiveView: extend `inbox_live_test.exs` — a manager sees the On Shift room row
  (assert dedicated id/mark); a staff member does **not** see it until
  rostered on, then sees it after `Ingress.report`. Extend `room_live_test.exs`
  — manager can post to On Shift; non-rostered staff is redirected from
  `/chats/<on_shift_id>` (membership check).
- `Sona.Shifts.Simulator` tests: keep light — assert a `:tick` calls
  `Ingress.report/2` (using a stub/monitor), and that it's not started when
  config is false. Avoid `Process.sleep`; use `assert_receive` on a testable
  message or `_ = :sys.get_state/1` to sync (AGENTS.md).

### Files to create / touch

| Path | Role |
|---|---|
| `priv/repo/migrations/*_add_role_to_users.exs` | `users.role` column |
| `lib/sona/accounts/user.ex` | `:role` Ecto.Enum (not cast) |
| `lib/sona/accounts.ex` | creator `:manager`, joiner `:staff` |
| `lib/sona/chat/room.ex` | add `:on_shift` to `type` enum |
| `lib/sona/shifts.ex` (new) | On Shift room + `reconcile_on_shift/2` |
| `lib/sona/shifts/ingress.ex` (new) | GenServer ingress seam |
| `lib/sona/shifts/simulator.ex` (new) | dev roster simulator (config-gated) |
| `lib/sona/application.ex` | start `Ingress` always; `Simulator` when enabled |
| `lib/sona_web/controllers/session_controller.ex` | ensure On Shift room on company create |
| `lib/sona_web/live/inbox_live.ex` (+ `.html.heex`) | `:on_shift` display name / badge |
| `lib/sona_web/live/room_live.ex` (+ `.html.heex`) | `:on_shift` header name / member count |
| `priv/repo/seeds.exs` | ensure On Shift room + initial roster report |
| `config/dev.exs` / `config/test.exs` | simulator toggles |
| `test/sona/accounts_test.exs`, `test/sona/chats_test.exs` | role + on_shift room guard |
| `test/sona/shifts_test.exs`, `test/sona/shifts/ingress_test.exs` (new) | context + ingress |
| `test/sona/shifts/simulator_test.exs` (new) | simulator tick → report |
| `test/sona_web/live/inbox_live_test.exs`, `room_live_test.exs` | On Shift visibility/posting |

### Reuse

- `Sona.Repo`, `Sona.PubSub`, `Sona.Chat.{Room,Membership}`, `Sona.Chats`
  membership/insert helpers (re-evaluate: reconcile does its own bulk
  membership writes rather than reusing `Chats.create_membership/2` per-row —
  fine; or reuse it inside a transaction).
- `Sona.Guide.ShiftData` — read-only by the optional simulator for plausible
  rosters. No shift tables introduced.
- Stdlib only for timers (`:timer.send_interval/3`); no new deps.

---

## Acceptance criteria / definition of done

- [ ] A `:manager` / `:staff` `role` exists on `users`; company creator is a
      manager, joiners are staff; the role is **not** settable via the user
      changeset/attrs
- [ ] Every company has exactly one `:on_shift` "On Shift" room; the manager is
      a member from creation; the room is idempotent under concurrent ensure
- [ ] `Sona.Shifts.Ingress.report(company_id, user_ids)` reconciles the On Shift
      group so its non-manager members are **exactly** the given roster, while
      all managers remain members at all times
- [ ] A second report with a changed roster converges membership to the new
      roster; an empty roster leaves only managers; user ids from other
      companies are ignored
- [ ] The `Ingress` GenServer is started in the app supervisor with a name and
      serializes reconciliations
- [ ] A manager can post to the On Shift group via the normal chat UI; current
      on-shift members receive the message in realtime (existing PubSub,
      single-insert rule unchanged)
- [ ] A staff member **not** in the current roster does not see the On Shift
      room in `/chats` and is redirected if they open `/chats/<on_shift_id>`;
      once rostered on, it appears and they can open/read/send
- [ ] `create_group_room` cannot create an `:on_shift` room (asserted)
- [ ] The dev roster simulator is off by default and only runs when
      `config :sona, :shift_simulator` is true; when on, it pushes roster
      snapshots to the ingress on an interval without `Process.sleep`
- [ ] No new tables; the `:on_shift` room type value is an app-level enum change
      with **no DB migration** for the value itself
- [ ] All `Sona.Shifts` + `Sona.Shifts.Ingress` public functions are tested;
      LiveView flows assert on elements; tests are network/scheduler-free
      (simulator disabled in test env)
- [ ] `mix precommit` passes (compile, format, credo --strict, test)

---

## Open questions

1. **Can non-manager on-shift staff post to the On Shift group, or is it
   manager-broadcast-only?** Current design uses `Chats.send_message` unchanged,
   so any member can post. A "broadcast-only / manager can post, staff can
   only read" rule would need a guard in `send_message` keyed on
   `room.type == :on_shift` and `user.role != :manager`. **Default decision:
   allow members to post** (chat parity); revisit if the product wants an
   announcement-only channel. Flag for confirmation.
2. **Should messages/roster changes update the chat list live?** Optional
   `{:on_shift_roster, count}` PubSub broadcast on company topic + inbox
   subscription. Plan marks this optional. Confirm whether the POC needs the
   member count to tick live in the header, or whether next-render is enough.
3. **Simulator roster logic.** Simple deterministic rotation vs. deriving from
   `Sona.Guide.ShiftData` upcoming shifts. Default: small rotation among
   seeded staff is enough to demonstrate "changes over time"; deriving from
   ShiftData is more realistic but more code. Confirm preference.
4. **Roster stability / flapping.** Roster-snapshot-replace will add+remove
   members on every report even if the roster is unchanged, because diffs are
   computed; the diff will simply be empty so no writes occur — confirm the
   implementation short-circuits when target == current (it should, by set
   diff). No user action needed; noted as an implementation guarantee to test.
5. **Multiple managers.** The plan supports many managers (all `:manager` users
   are ensured members), but there's no UI to promote someone to manager in
   this slice (the creator is the only manager unless seeded otherwise).
   Confirm that's acceptable for the POC, or if we should seed a second
   manager.
6. **On Shift room and the existing `rooms(company_id, type, name)` unique
   index.** `:on_shift` + `"On Shift"` is unique per company by that index —
   good. Confirm we keep the room name non-null "On Shift" (we do) so NULL
   uniqueness semantics never bite.

---

## Next step after plan approval

Implement in roughly this order: (1) `users.role` migration + Accounts → (2)
`Room` enum + `Sona.Shifts` context → (3) `Ingress` GenServer + supervisor →
(4) SessionController + seeds → (5) Inbox/Room display tweaks → (6) optional
simulator → (7) tests + `mix precommit`. Optionally convert to `issues/` via
`plan-to-issues`.