---
id: 027
title: `InboxLive` + `RoomLive` `:on_shift` display + LiveView tests
status: todo
created: 2026-07-14
depends_on: [024, 025]
---

## Goal
Make the On Shift group recognizable in `InboxLive` (display name `"On Shift"`, dedicated marker) and `RoomLive` (header name, member count), with LiveView element assertions covering the user-facing flows: manager visibility, staff-on-roster visibility, staff-not-on-roster denial, and manager posting. **No new route** — the On Shift group rides the existing `/chats/<id>` route.

## Context
See `plans/on-shift-broadcast-group.md` "Routes / LiveView", "Realtime contract", and the user flows D and E.

Layering:
- `InboxLive.room_display_name/2` (or the equivalent mapping function) gains an `:on_shift` clause → `"On Shift"`. The room row in the inbox gets a dedicated marker (e.g. `data-room-type="on-shift"` and a `hero-bolt` icon) so it reads as a managed channel, not a user-created group.
- `RoomLive.get_header_name/1` (or equivalent) gains an `:on_shift` clause → `"On Shift"`. The header can show a member count for `:on_shift` rooms; the count is the preloaded memberships size — a live-ticking count via a PubSub broadcast is **out of scope for this slice** (deferred; see plan open question #2 and "Out of scope" — next-render is acceptable for the POC).
- Only members see the On Shift room in the inbox (managers always; staff while on shift) because `Chats.list_rooms_for_user/1` is membership-backed — no inbox filter change is needed for visibility; the display layer just needs the new clause and marker.
- `RoomLive`'s existing membership check already denies access to non-members; the test asserts a non-rostered staff is redirected from `/chats/<on_shift_id>`.

Styling: use daisyUI semantic tokens + Tailwind utilities consistent with the 010–014 retheme; `hero-bolt` for the marker icon. Keep `AGENTS.md` rules: only `app.css`/`app.js` bundled; no `<script>` in HEEx; no `@apply`; Tailwind v4.

Open question resolved for this slice (per plan defaults): **non-manager on-shift staff can post to the On Shift group** (chat parity — `Chats.send_message/3` is unchanged). No posting guard is added.

## Acceptance criteria
- [ ] `InboxLive` maps `:on_shift` rooms to display name `"On Shift"`
- [ ] The On Shift row in the inbox carries a dedicated marker (e.g. `data-room-type="on-shift"` and a `hero-bolt` icon), distinct from `:direct` and `:group` rows
- [ ] `RoomLive` maps `:on_shift` rooms to header name `"On Shift"`
- [ ] `RoomLive` shows a member count in the header for `:on_shift` rooms (preloaded memberships size)
- [ ] `test/sona_web/live/inbox_live_test.exs` (extended) — a manager sees the On Shift row with its dedicated marker; a staff member does **not** see the On Shift row before any roster report; after `Sona.Shifts.Ingress.report(company_id, [staff_id])`, the staff member sees the On Shift row
- [ ] `test/sona_web/live/room_live_test.exs` (extended) — a manager can post to the On Shift room via `render_submit/2`; a staff member not in the current roster is redirected from `/chats/<on_shift_id>` (existing membership check); a staff member in the current roster can open, read, and send
- [ ] All LiveView assertions use `has_element?` with DOM ids/selectors (no raw-HTML regex per `AGENTS.md`); tests are network-free (simulator disabled in test env per 028)
- [ ] `mix precommit` passes for this slice

## Notes
- 2026-07-14: created from `plans/on-shift-broadcast-group.md` ("Routes / LiveView", "Realtime contract", "Tests", acceptance criteria for flows D and E). The optional `{:on_shift_roster, count}` PubSub broadcast on `shifts:company:<company_id>` (plan open question #2) is **out of scope for this slice** — next-render is acceptable for the POC. A follow-up issue can pick it up if the product wants the header count to tick live without a navigation.
- 2026-07-14: open question #1 (non-manager staff posting) resolved to **allow** per the plan's default — chat parity. No posting guard is added in this issue. Deps: [024, 025] (does not depend on 026 because the LiveView test setup uses `Sona.Shifts.ensure_on_shift_room/1` and `Sona.Shifts.Ingress.report/2` directly; the SessionController wiring is covered by 026's own tests).
