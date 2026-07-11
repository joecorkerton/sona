---
id: 019
title: GuideLive — /guide chat-style AI guide conversation
status: todo
created: 2026-07-11
depends_on: [018]
---

## Goal
Build `GuideLive`, a new mobile-first chat-style LiveView at `/guide` for the AI shift guide conversation: streams, PubSub, a sticky composer, a "thinking" state, and error handling. It models `RoomLive` closely but the counterpart is the LLM, visually distinct from a coworker.

## Context
See `plans/ai-shift-guide.md` sections "Routes", "LiveView surfaces (mobile-first)", "Realtime contract", and "Files to create / touch".

Routes (`lib/sona_web/router.ex`) — inside the existing `live_session :current_user`:
```elixir
live "/guide", GuideLive
```
`/guide` is a parallel top-level route (not nested under `/chats/...`), keeping the Guide distinct in URL space. It rides the existing `live_session :current_user` (`on_mount: [{UserAuth, :mount_current_user}, {UserAuth, :require_user}]`) so `current_scope` flows through per `AGENTS.md`.

`GuideLive` (models `RoomLive`):
- Template starts with `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- `mount/3` **auto-ensures** the conversation: `Sona.Guide.ensure_conversation/1` runs every mount, so `/guide` always has a conversation row even on a first visit (no "Set up your guide" gate). On a fresh conversation the stream is empty and the `hidden only:block` empty state renders. There is no "new guide" action and no confirm step.
- Stream `:guide_messages` (not a list); empty state via `hidden only:block`.
- Header shows "Sona Guide" + a guide icon (e.g. `<.icon name="hero-sparkles" .../>`) — distinct from a room header.
- Messages: assistant (guide) left-aligned with guide bubble style; user right-aligned — consistent visual language with `RoomLive` but with a guide accent so it never reads as a coworker.
- Sticky composer form `id="guide-compose-form"`, `phx-submit="send"`.
- Subscribe to `"guide:user:#{user.id}"` on `connected?`.

Realtime contract (from the plan + AGENTS.md):
- On `handle_event("send", ...)`: call `Sona.Guide.send_user_message/2`. **Do not `stream_insert` the user message locally** — rely on the broadcast round trip (single-insert-per-receiver rule, same as `RoomLive` / `basic-chat-poc.md`).
- Disable composer + show "thinking" until the assistant's `{:new_guide_message, msg}` arrives. `send_user_message/2` broadcasts the same `{:new_guide_message, msg}` tag for both `:user` and `:assistant`; there is no separate `{:assistant_reply, _}` event.
- `handle_info({:new_guide_message, msg}, socket)`: `stream_insert(:guide_messages, msg, at: -1)`. **Re-enable** the composer when the message's `role` is `:assistant` (the reply landed); a `:user` broadcast leaves "thinking" on.
- On `{:error, _}` from `send_user_message/2`: show a flash error and keep the user's text in the input so they can retry.

Styling: use the **same** daisyUI semantic tokens (`btn`, `bg-base-*`, `text-base-content`) so the 010–014 retheme picks it up automatically. Use `<.icon name="hero-sparkles" .../>` (or similar) for the guide avatar. Keep AGENTS.md: only `app.css`/`app.js` bundled; no `<script>` in HEEx; no `@apply`; Tailwind v4.

Files to create:
- `lib/sona_web/router.ex` — add `live "/guide", GuideLive`
- `lib/sona_web/live/guide_live.ex`
- `lib/sona_web/live/guide_live.html.heex`
- `test/sona_web/live/guide_live_test.exs`

Test constraints (AGENTS.md / plan): `Phoenix.LiveViewTest` + `LazyHTML`; assert on elements/IDs, never raw HTML; `render_submit/2` / `render_change/2` drive forms; stub the LLM (no network).

## Acceptance criteria
- [ ] `lib/sona_web/router.ex` adds `live "/guide", GuideLive` inside the existing `live_session :current_user` (no new live_session, current_scope flows through)
- [ ] Template starts with `<Layouts.app flash={@flash} current_scope={@current_scope}>`
- [ ] `mount/3` auto-ensures the conversation via `Sona.Guide.ensure_conversation/1` — opening `/guide` with no existing conversation renders the `hidden only:block` empty state (no "Set up" gate); the conversation row exists before any message is sent
- [ ] Messages render from a `:guide_messages` **stream** (not a list) with `phx-update="stream"` + a DOM id on the parent; each child keyed by its streamed id
- [ ] The guide's messages are visually distinct from a coworker: header shows "Sona Guide" + a guide icon; guide bubbles use a guide accent (left-aligned assistant, right-aligned user), consistent with `RoomLive` but clearly the LLM
- [ ] Composer form has `id="guide-compose-form"` and `phx-submit="send"`; it is sticky and usable at ~390px (mobile-first)
- [ ] On `send`, `Sona.Guide.send_user_message/2` is called and the user message is **not** inserted locally — the broadcast round-trip drives the insert (single insert per client)
- [ ] `handle_info({:new_guide_message, msg}, socket)` does `stream_insert(:guide_messages, msg, at: -1)`; the composer re-enables only when `msg.role == :assistant`; a `:user` broadcast keeps "thinking" on
- [ ] Error path: on `{:error, _}` from `send_user_message/2` a flash error is shown and the user's text stays in the input (retryable)
- [ ] Re-opening `/guide` restores the full guide history (proactive + exchanges)
- [ ] `test/sona_web/live/guide_live_test.exs` asserts: open `/guide`, see seeded proactive guide bubble, submit a follow-up via `render_submit/2` on `#guide-compose-form`, see the stub assistant reply as a new guide bubble, single insert per client, composer disabled state handled, and the error path (flash + retained input) — all network-free via `Sona.Guide.LLM.Stub`
- [ ] `mix credo --strict` clean for the new modules

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Routes", "LiveView surfaces", "Realtime contract"). Depends on the context (018). Modeling on `RoomLive` (streams/PubSub pattern) per `basic-chat-poc.md`.