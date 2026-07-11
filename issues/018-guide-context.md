---
id: 018
title: Guide context — conversations, messages, send_user_message, company scoping
status: todo
created: 2026-07-11
depends_on: [015, 016, 017]
---

## Goal
Build the `Sona.Guide` context module: the public API that owns guide conversations and messages, the LLM reply loop, PubSub broadcasting, and company-scoped access. LiveViews (019, 020) and seeds (021) call only into `Sona.Guide` — never `Repo`.

## Context
See `plans/ai-shift-guide.md` sections "Layering", "Context (`Sona.Guide`) public API", "Realtime contract", and "PubSub topic".

Layering invariant: `Sona.Guide` depends only on `Sona.Accounts` (`%User{}` / `%Company{}`) and `Sona.Repo`. **`Sona.Guide` does not call `Sona.Chats` and vice versa.** All APIs take `%User{}` and filter by `user.company_id`; a guide conversation belongs to exactly one `(company_id, user_id)` pair.

Public API to deliver (from the plan):
- `ensure_conversation(%User{})` — get_or_create the user's guide conversation; rescue the unique constraint on `user_id` and re-fetch (idempotent). Paired with `unique_index(:guide_conversations, [:user_id])` from 016.
- `list_messages(%User{} | %GuideConversation{})` — last N `guide_messages`, oldest→newest, preload nothing (no user association on guide messages).
- `latest_guide_summary(%User{})` — returns `%{teaser: String.t() | nil, inserted_at: DateTime}` (the map, **not** the atom `nil`) for the Inbox Guide section. **Auto-ensures** the conversation (same idempotent `ensure_conversation/1`), so for a signed-in user it always returns the map; the `teaser` field is `nil` only when the conversation has no messages yet (fresh, unseeded user).
- `send_user_message(%User{}, text)` — insert `:user` message → broadcast `{:new_guide_message, msg}` → rebuild system prompt via `Sona.Guide.Prompt.build/2` with `Sona.Guide.ShiftData.for/1` → call `Sona.Guide.LLM.impl().reply/3` with `system_prompt` + `history` (the list of prior `guide_messages` oldest→newest, mapped to `%{role, content}` — **includes the seeded proactive `:assistant` message**; do not filter it out) + `text` → insert `:assistant` message → broadcast `{:new_guide_message, assistant_msg}`. Returns `{:ok, assistant_msg}` / `{:error, reason}`.
- `seed_proactive_message(%User{}, body)` — used by seeds (021) to insert the hardcoded `:assistant` proactive message with **no LLM call**. Re-fetches the conversation internally via `ensure_conversation/1`, so callers pass only `%User{}` + body; no `%GuideConversation{}` argument.
- `subscribe_guide(%User{})`.

Realtime contract (from the plan):
```elixir
def subscribe_guide(user), do: Phoenix.PubSub.subscribe(Sona.PubSub, topic(user.id))
defp topic(user_id), do: "guide:user:#{user_id}"
```
- `send_user_message/2` broadcasts the same `{:new_guide_message, msg}` tag for both the `:user` message and the `:assistant` reply — **no separate `{:assistant_reply, _}` event**.
- The LLM call runs **inline** in the LiveView process for this POC (simplest; a single user's guide is low-traffic). Archived in "Open questions" as a deferred refactor to a `Task` if latency bites.

Files to create/touch:
- `lib/sona/guide.ex` — the context
- `test/sona/guide_test.exs` — `Sona.DataCase` context tests

Test constraints (AGENTS.md / plan):
- `ensure_conversation/1` idempotent (concurrent calls → one row, rescue unique constraint).
- `send_user_message/2` happy path inserts a `:user` + `:assistant` message and broadcasts both (use the stub from 015 — no network).
- Error path: stub returns `{:error, _}` → only the `:user` message is inserted (or rolled back per decision) and `{:error, _}` returned; document the chosen behaviour in `## Notes`.
- Company scoping: a user from company B cannot read/scope another company's guide.
- Avoid `Process.sleep/1` / `Process.alive?/1`; use `Process.monitor/1` + `assert_receive {:DOWN, ...}` for any teardown, `_ = :sys.get_state/1` to sync.

## Acceptance criteria
- [ ] `lib/sona/guide.ex` exposes `ensure_conversation/1`, `list_messages/1`, `latest_guide_summary/1`, `send_user_message/2`, `seed_proactive_message/2`, `subscribe_guide/1`; every lookup is company-scoped via `user.company_id` (`list_messages/1` accepts either `%User{}` or `%GuideConversation{}`, but a `%User{}` is scoped to that user's conversation and a `%GuideConversation{}` is verified to belong to the caller's company); LiveViews call only this module (never `Repo`)
- [ ] `ensure_conversation/1` is idempotent: concurrent calls yield one conversation row (rescues the `user_id` unique constraint and re-fetches)
- [ ] `latest_guide_summary/1` auto-ensures the conversation and always returns the summary **map** for a signed-in user (never the atom `nil`); the map's `teaser` is `nil` only when no messages exist yet (fresh, unseeded user)
- [ ] `send_user_message/2` inserts a `:user` message, broadcasts `{:new_guide_message, msg}`, rebuilds the system prompt via `Sona.Guide.Prompt.build/2` + `Sona.Guide.ShiftData.for/1`, calls `Sona.Guide.LLM.impl().reply/3`, inserts an `:assistant` message, and broadcasts `{:new_guide_message, assistant_msg}`; returns `{:ok, assistant_msg}` on success
- [ ] `history` passed to `reply/3` is the full list of prior `guide_messages` oldest→newest mapped to `%{role, content}`, **including** the seeded proactive `:assistant` message (not filtered out)
- [ ] `send_user_message/2` error path (stub returns `{:error, _}`) returns `{:error, _}`, and the chosen `:user`-message-on-error behaviour (insert-then-return-error, or rollback/no-insert) is **recorded in `## Notes`** with a one-line rationale before this criterion is checked off
- [ ] `seed_proactive_message/2` inserts an `:assistant` message, makes **no** LLM call, invokes **no** `Prompt.build/2`, and re-fetches the conversation internally (caller passes only `%User{}` + body)
- [ ] Company scoping: a user from company B cannot read or act on company A's guide conversation; all lookups filter by `user.company_id`
- [ ] PubSub topic is `"guide:user:#{user_id}"`; both broadcasts use the `{:new_guide_message, msg}` tag (no separate assistant event)
- [ ] `Sona.Guide` does **not** call `Sona.Chats` (and vice versa)
- [ ] `test/sona/guide_test.exs` covers all the above using `Sona.Guide.LLM.Stub` (no network, no `ANTHROPIC_API_KEY`); tests pass

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Context public API", "Realtime contract", "PubSub topic", "Context tests"). Depends on the LLM seam (015), schemas (016), and prompt/data (017). The error-path insert-vs-rollback decision should be recorded here when implementing.