---
id: 016
title: Guide migration + schemas (GuideConversation, GuideMessage)
status: todo
created: 2026-07-11
depends_on: []
---

## Goal
Land the persistence layer for the AI shift guide: one migration creating `guide_conversations` + `guide_messages`, plus their Ecto schemas. One guide conversation per user (unique index), messages with an `Ecto.Enum` role of `:user` / `:assistant`, company-scoped.

## Context
See `plans/ai-shift-guide.md` sections "Data model" and "Migration".

Schema (from the plan):
```
guide_conversations
  id              uuid PK
  company_id      FK companies not null    -- tenancy
  user_id         FK users not null        -- the employee being coached
  timestamps
  unique(user_id)                          -- one guide conversation per user
  index (company_id)

guide_messages
  id              uuid PK
  conversation_id FK guide_conversations not null
  role            Ecto.Enum, values: [:user, :assistant]   -- :assistant = the LLM
  body            text not null
  timestamps
  index (conversation_id, inserted_at)
```

Key constraints (plan + `AGENTS.md`):
- **No `:system` role** in the table — the system prompt is rebuilt fresh per LLM call and is not stored as a message. `guide_messages` stores only turns that appear in the UI / are replayed as history (`:user`, `:assistant`).
- `role` uses `Ecto.Enum` (schema field `:role, Ecto.Enum, values: [:user, :assistant]`), **not** a DB enum — easy to extend later (e.g. `:tool`).
- `body` is text → schema field is `:body, :string` (AGENTS.md: text columns still use `:string`).
- `company_id` is denormalised onto `guide_conversations` (also derivable via `user.company_id`); set it from `user.company_id` at insert, never from user input. It is **not** in any `cast`.
- `guide_conversations.user_id` has `unique_index(:guide_conversations, [:user_id])`; `guide_messages` has an index on `(conversation_id, inserted_at)` for ordered history.
- `guide_messages` has **no** `user` association to preload (the only user is the conversation's owner; messages are `:user`/`:assistant`, not per-author rows). The Inbox teaser and history come from `guide_messages.body` + `inserted_at` only.
- Use `mix ecto.gen.migration create_guide_tables` → `priv/repo/migrations/*_create_guide_tables.exs`.

Files to create:
- `priv/repo/migrations/*_create_guide_tables.exs`
- `lib/sona/guide/conversation.ex` — `GuideConversation` schema
- `lib/sona/guide/message.ex` — `GuideMessage` schema (`:role, Ecto.Enum, ...`)

No context module in this issue — the public `Sona.Guide` API on top of these schemas lives in 018.

## Acceptance criteria
- [ ] `mix ecto.gen.migration create_guide_tables` created `*_create_guide_tables.exs`
- [ ] Migration creates `guide_conversations` with `id` (uuid PK), `company_id` (FK `companies`, not null), `user_id` (FK `users`, not null), timestamps, a `unique_index` on `[:user_id]`, and an index on `[:company_id]`
- [ ] Migration creates `guide_messages` with `id` (uuid PK), `conversation_id` (FK `guide_conversations`, not null), `role` (`:string` column — wrapped as `Ecto.Enum` in the schema, matching the existing `rooms.type` recipe of `:string` column + `Ecto.Enum` schema field), `body` (`:string`, not null — AGENTS.md: text columns use `:string`), timestamps, and an index on `[[:conversation_id, :inserted_at]]`
- [ ] `mix ecto.migrate` (and `mix ecto.rollback` → `mix ecto.migrate`) round-trips cleanly
- [ ] `GuideConversation` schema defines `company_id`, `user_id`, timestamps; no `cast` includes programmatically-set `company_id`/`user_id`
- [ ] `GuideMessage` schema defines `role` as `Ecto.Enum, values: [:user, :assistant]` and `body` as `:string`; no `:system` role exists
- [ ] No `user` association to preload on `GuideMessage`
- [ ] `mix compile` clean; `mix credo --strict` clean for the new modules

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Data model", "Migration"). No deps — schemas + migration are independent of the LLM seam (015) and the prompt builder (017); the context (018) composes them.