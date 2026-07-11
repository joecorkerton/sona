# Plan: AI Shift Guide

**In-repo copy:** [`plans/ai-shift-guide.md`](ai-shift-guide.md) (canonical for the project;
keep in sync when revising).

## Context

Sona is a hospitality communications POC (see `README.md`, `docs/task-info.md`,
`docs/market-research.md`, `plans/basic-chat-poc.md`). The basic chat (1-1 +
group, company-scoped, mobile-first LiveView, PubSub, streams) is the spine of
the app and is functionally in place (`lib/sona/chats.ex`,
`lib/sona_web/live/inbox_live.ex`, `lib/sona_web/live/room_live.ex`, seeds,
tests). Styling/branding work for the chat is tracked under issues 010–014.

The market research (`docs/market-research.md`) deliberately picks **basic
expandable chat** as the spine and adds a **belonging / AI personalised coach**
on top rather than chasing a full Slack clone. Of the belonging ideas surveyed,
the most compelling adoption driver is:

> **Personalised coach**: using data from chats, plus work schedules, overtime
> data and demand modelling, give shift-specific AI guidance to each team member
> ahead of their shift (daily plus weekly review).

This plan specifies the **first vertical of the AI personalised coach**: an
**AI-powered shift guide** — a chat-style conversation with an LLM that is
clearly separated from human chats, where the LLM proactively sends the user a
message before their shift to prepare them, and the user can reply with
questions / follow-ups. The goal is to **drive adoption by proactively
providing value to employees ahead of their shift**.

This is distinct from the human chats (1-1 / group): it lives under a dedicated
**Guide** section on `/chats`, opens into a familiar chat surface, but the other
participant is an LLM, not a coworker.

**Decisions confirmed with the user (see `## Open questions` for residual
gaps):**

1. **Persistence:** dedicated guide tables (`guide_conversations` +
   `guide_messages`), **not** a reuse of `rooms`/`messages` with a `:guide`
   room type. A fresh LiveView + streams + PubSub from scratch, modelled on
   `RoomLive`. This is cleanest domain isolation and matches the "interface
   similar to the other chats" goal without contaminating the human chat
   schema (`rooms.type` enum, DM picker, room list) with bot semantics.
2. **LLM client:** wrap `req_llm` behind a small `Sona.Guide.LLM` client with a
   behaviour; production/dev call the real Anthropic API (key from
   `ANTHROPIC_API_KEY` / `config :req_llm`), tests inject a stub via config so
   they never hit the network.
3. **Proactive scope (this POC):** the initial pre-shift message is
   **generated manually by the seeds** (hardcoded body) so we can validate the
   full prompt + injected data shape without a live key. The interactive
   reply loop is wired to the real LLM in dev/prod. Any **automated scheduler**
   that fires a message before a real shift is explicitly **deferred** to a
   later plan (it needs real shift data, which this POC only fakes in seeds).

The shift/overtime/demand data is **not persisted** in this slice — per the
user's instruction we hardcode that data in the seeds and pass it manually into
the initial-message prompt. No `shifts` / `overtime` / `demand` tables.

---

## Goals

### In scope (this slice)

- A **Guide** section on `/chats`, visually and navigationally **separate** from
  the Chats room list, that opens an AI conversation.
- A **chat-style interface** (header / scrollable messages / sticky composer)
  that looks and behaves like `RoomLive` — streams, PubSub, mobile-first — but
  the counterpart is the LLM, not a coworker.
- The LLM **proactively sends a message before the user's shift** to prepare
  them, derived from a single prompt with injected data: **previous and
  upcoming shifts, overtime data, and demand modelling** for the user's site.
  In this POC that proactive message is **seeded manually** (hardcoded body) to
  prove the data shape; the real LLM call is wired for the **follow-up reply**
  loop.
- User can **reply with questions / follow-ups**; the LLM responds, threaded as
  a normal conversation with the prior guide messages as context.
- Use **`req_llm`** for LLM requests (Anthropic provider).
- **No new domain tables for shift / overtime / demand data** — hardcoded in
  seeds and passed into the prompt manually.
- Public context functions tested; LiveView flows covered with element
  assertions; `mix precommit` green.

### Out of scope (later plans)

- **Automated proactive delivery** (cron / scheduler / Quantum / Oban) that
  fires a guide message before a real shift. This slice seeds the proactive
  message manually; automation needs real shift data and is its own plan.
- **Persisting shift / overtime / demand data** (`shifts`, `overtime`,
  `demand_forecasts` tables). Hardcoded in seeds for now.
- Weekly review / digest generation (market research mentions "daily plus
  weekly review"); **daily pre-shift** only for this POC.
- Tool calling / web search / function calling through the LLM.
- Streaming token-by-token to the browser (we render the complete reply; see
  "Streaming" in Implementation notes).
- Push notifications / email delivery of the proactive message.
- Auth on the LLM side (rate limiting, per-user quotas, abuse guards).
- Multi-company LLM config / per-company model selection.

---

## Product / user flows

### A. Discover the Guide from `/chats`

1. Signed-in user opens `/chats` (InboxLive). Below the company header / invite
   link / chats room list, a clearly separated **"Guide" section** is shown
   (distinct heading + visual treatment, not just another row in the chats
   list).
2. The Guide section shows a single entry — the user's AI shift guide — with a
   short teaser of the latest guide message (e.g. "Here's how tomorrow looks…")
   and a tap target.
3. Tapping it opens `/guide` (the Guide conversation LiveView). Only one guide
   conversation exists per user; there is no "new guide" action.

### B. Read the proactive pre-shift message

1. On opening `/guide`, the user sees the conversation: the proactive
   pre-shift message from the guide (seeded), plus any prior follow-ups.
2. The guide's first message is clearly **from the guide** (distinct bubble
   style / name — e.g. "Sona Guide" with an icon), not from a coworker.
3. This message prepares the user for their upcoming shift using the injected
   shift / overtime / demand data (see the prompt shape under Architecture).

### C. Reply with a follow-up question

1. The user types a question / follow-up in the sticky composer and sends.
2. Their message appears in the conversation (right-aligned, own-style —
   consistent with `RoomLive`).
3. The app calls the LLM with the **conversation history** (system prompt +
   proactive message + prior exchanges + the new user message) and, on
   success, the guide's reply appears (left-aligned, guide-style).
4. While the LLM is thinking, the composer is disabled / a subtle "thinking"
   indicator is shown. On error, a flash error is shown and the user's message
   remains in the input so they can retry.

### D. Persistence / continuity

1. All guide messages (proactive + user + assistant) persist in
   `guide_messages`, so re-opening `/guide` restores the full history.
2. The Guide section on `/chats` always reflects the latest guide message.
3. Company-scoped: a user's guide conversation belongs to their company; never
   visible to other companies.

---

## Architecture / design

### Layering

```
┌──────────────────────────────────────────────┐
│  LiveViews (UI only: assigns, events, HEEx)  │
│  InboxLive (adds Guide section) · GuideLive  │
├──────────────────────────────────────────────┤
│  SonaWeb.UserAuth (existing on_mount)        │
├──────────────────────────────────────────────┤
│  Contexts                                    │
│  Sona.Accounts (existing)                    │
│  Sona.Chats   (existing, human chat)         │
│  Sona.Guide   (new — conversations/messages) │
│  Sona.Guide.LLM (new — req_llm wrapper)      │
│  Sona.Guide.Prompt (new — prompt builder)    │
├──────────────────────────────────────────────┤
│  Schemas + Repo (Postgres)                   │
│  GuideConversation · GuideMessage            │
├──────────────────────────────────────────────┤
│  Phoenix.PubSub  topic "guide:user:{user_id}"│
└──────────────────────────────────────────────┘
```

- New domain under `Sona.Guide`. **`Sona.Guide` does not call `Sona.Chats` and
  vice versa** — the two contexts stay decoupled. `Sona.Guide` depends only on
  `Sona.Accounts` (`%User{}` / `%Company{}`) and `Sona.Repo`.
- All writes/queries go through `Sona.Guide`; LiveViews never touch `Repo`.
- Company scoping: every `Sona.Guide` API takes `%User{}` and filters by
  `user.company_id`. A guide conversation belongs to exactly one `(company_id,
  user_id)` pair.

### Data model

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

**Notes:**
- **No `:system` role in the table.** The system prompt is built fresh from the
  injected shift/overtime/demand data on each LLM call and is not stored as a
  message — it's instructions, not conversation history. `guide_messages` only
  stores turns that should appear in the UI and be replayed as history
  (`:user` and `:assistant`). This avoids storing stale injected data.
- `role` uses `Ecto.Enum` (schema field `:role, Ecto.Enum, values: [:user,
  :assistant]`), not a DB enum — easy to extend later (e.g. `:tool`).
- **One conversation per user** enforced by `unique_index(:guide_conversations,
  [:user_id])`. Idempotent `ensure_conversation/1` rescues the unique
  constraint and re-fetches (same pattern as `Accounts.get_or_create_user`).
- `company_id` is denormalised onto `guide_conversations` (also derivable via
  `user.company_id`) for cheap company-scoped queries and to keep the invariant
  explicit; set it from `user.company_id` at insert, never from user input.

### LLM client (`Sona.Guide.LLM`)

A thin module + behaviour so tests don't hit the network:

```elixir
defmodule Sona.Guide.LLM do
  @callback reply(system_prompt :: String.t(), history :: [map()], user_text :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
end

# Default impl (dev/prod) — uses req_llm + Anthropic, key from env/config
defmodule Sona.Guide.LLM.Anthropic do
  @behaviour Sona.Guide.LLM
  def reply(system_prompt, history, user_text) do
    messages = history ++ [%{role: :user, content: user_text}]
    model = Application.get_env(:sona, :guide_model, "anthropic:claude-3-5-haiku-20241022")

    {:ok, resp} =
      ReqLLM.generate_text(model, messages, system_prompt: system_prompt)

    {:ok, ReqLLM.Response.text(resp)}
  end
end
```

> **Call shape is canonical here.** `history` is a list of loose maps with
> `:role`/`:content` keys (or `%ReqLLM.Message{}` structs) — keys that
> `ReqLLM.Context.normalize/2` accepts. The system prompt is passed via the
> **`system_prompt:` option**, not as a `{:system, ...}` tuple in the messages
> list (a 2-tuple with an atom head is not one of the shapes `normalize/2`
> accepts and will not be treated as a system message). See "req_llm call shape"
> below for the fallback form.

- **Module resolved via config**, not hard-coded: `Sona.Guide.LLM.impl/0`
  returns `Application.get_env(:sona, :guide_llm_impl, Sona.Guide.LLM.Anthropic)`.
  `config/test.exs` sets `config :sona, :guide_llm_impl, Sona.Guide.LLM.Stub`
  (the stub is a `@behaviour Sona.Guide.LLM` in `test/support/`). Dev/prod leave
  it unset so the `Sona.Guide.LLM.Anthropic` default applies (see Config note).
- **Model spec** is config-driven: `config :sona, :guide_model,
  "anthropic:claude-3-5-haiku-20241022"` (override per env without code
  changes). The dated form is used because `claude-3-5-haiku` is **not** a
  confirmed LLMDB catalog id; confirm the exact id against the installed
  `req_llm`/`llm_db` version when implementing and pin it in config.
- **API key**: `req_llm` reads `ANTHROPIC_API_KEY` from env / application config
  (`config :req_llm, :anthropic_api_key, ...`). In dev, the user supplies the
  key via env var; seeds do **not** require it (the proactive message is
  hardcoded). Tests never need a key.
- `history` passed to `reply/3` is the list of prior `guide_messages`
  (oldest→newest, mapped to `%{role, content}`), so follow-ups have context.
  It **includes the seeded proactive `:assistant` message** as the first
  assistant turn — *do not filter the seed out*; without it the LLM has no
  record of what it pre-emptively told the user (see "req_llm call shape").

### Prompt builder (`Sona.Guide.Prompt`)

Builds the **single system prompt** with the injected data. Because shift /
overtime / demand data is not persisted in this POC, the builder takes that
data as an explicit struct/map argument (hardcoded in seeds + tests):

```elixir
defmodule Sona.Guide.Prompt do
  def build(%User{} = user, shift_data) do
    # shift_data = %{previous_shifts: [...], upcoming_shifts: [...],
    #                 overtime: [...], demand: %{...}, site: %Company{}}
    # Returns a single string: persona + goal + the injected data + output rules.
  end
end
```

- The prompt is **one string** with the data injected (the user explicitly
  asked for "one prompt that has the data injected into the prompt, which gets
  sent to the LLM for the initial message that goes to the user").
- The data shape is defined but the data itself is **temporary/hardcoded** for
  now (see `Sona.Guide.ShiftData` below). No DB tables.
- The proactive seeded message is hand-written to look like what the LLM *would*
  return from this prompt, so we can validate the data shape end-to-end without
  spending tokens / needing a key to seed.

### Temporary shift data (`Sona.Guide.ShiftData`)

A module with hardcoded sample data for the seeded demo user(s), representing
the previous and upcoming shifts, overtime data, and demand modelling for the
site they work at. Pure functions returning maps/structs — no persistence:

```elixir
defmodule Sona.Guide.ShiftData do
  def for(%User{} = user) do
    %{
      previous_shifts: [...],     # last few shifts (role, start, end, notes)
      upcoming_shifts: [...],      # the shift(s) the guide is prepping them for
      overtime: [...],             # overtime hours / context
      demand: %{...},              # demand modelling for the site
      site: user.company
    }
  end
end
```

- Hardcoded values for the seeded users (Alice/Bob/Charlie from `seeds.exs`).
- `Sona.Guide.Prompt.build/2` consumes this. Only the **LLM** path uses the
  prompt builder — the seeded proactive message is a hand-written stand-in
  (`seed_proactive_message/2` makes no LLM call and invokes no `Prompt.build/2`);
  it is shaped like what the prompt+LLM combo would return so we can validate
  the data shape end-to-end without spending tokens. The actual
  prompt→message flow is exercised only on follow-up replies.

### Routes

```elixir
# inside the existing live_session :current_user
live "/guide", GuideLive
```

- `/guide` sits under the existing `live_session :current_user`
  (`on_mount: [{UserAuth, :mount_current_user}, {UserAuth, :require_user}]`),
  so `current_scope` flows through per AGENTS.md. No new controller, no new
  live_session.
- It is **not** nested under `/chats/...` — it's a parallel top-level route,
  which keeps the Guide clearly distinct from chats in the URL space and the
  router.

### LiveView surfaces (mobile-first)

| Route | LiveView | Purpose |
|---|---|---|
| `/chats` | `InboxLive` (existing, **extended**) | Chats room list **+ new Guide section** |
| `/guide` | `GuideLive` (new) | AI guide conversation: stream + composer + PubSub |

**`GuideLive`** models `RoomLive` closely:
- `<Layouts.app flash={@flash} current_scope={@current_scope}>` start.
- `mount/3` **auto-ensures** the conversation on mount:
  `Sona.Guide.ensure_conversation/1` runs every mount, so `/guide` always has
  a conversation row even on a first visit (no "Set up your guide" gate).
  On a fresh conversation the stream is empty and the `hidden only:block`
  empty state renders. There is no "new guide" action and no confirm step.
- Stream `:guide_messages` (not a list); empty state via `hidden only:block`.
- Header shows "Sona Guide" + guide icon (distinct from room header).
- Messages: assistant (guide) left-aligned with guide bubble style; user
  right-aligned — consistent visual language with `RoomLive` but with a guide
  accent so it never reads as a coworker.
- Sticky composer form `id="guide-compose-form"`, `phx-submit="send"`.
- Subscribe to the PubSub topic on `connected?`.

**`InboxLive` extension:**
- Add a **Guide section** visually separated from the Chats `<section>` (separate
  heading like "Guide", distinct card/border treatment, **below** the chats list
  or in a clearly separate region — not interleaved with room rows).
- Shows a single entry: the user's guide conversation with the latest guide
  message teaser + a `<.link navigate={~p"/guide"}>`.
- Fetch via `Sona.Guide.latest_guide_summary/1`, which **auto-ensures** the
  conversation (same idempotent `ensure_conversation/1` as `GuideLive`), so it
  never returns `nil` for a signed-in user — the teaser is `nil`/empty only
  when the conversation has no messages yet (fresh user, not yet seeded). In
  that case the entry still links to `/guide` with a "Set up your guide" CTA;
  `GuideLive.mount` creates the row on open. Empty state via `hidden only:block`.

### Realtime contract

```elixir
# Sona.Guide
def send_user_message(user, text) do
  # insert :user message, broadcast {:new_guide_message, msg}, then call LLM,
  # insert :assistant message, broadcast {:new_guide_message, assistant_msg}.
end

def subscribe_guide(user), do: Phoenix.PubSub.subscribe(Sona.PubSub, topic(user.id))
defp topic(user_id), do: "guide:user:#{user_id}"
```

`GuideLive`:
- subscribe on `connected?`,
- on `handle_event("send", ...)`: call `Sona.Guide.send_user_message/2`. **Do
  not `stream_insert` the user message locally** — rely on the broadcast round
  trip (same single-insert-per-receiver rule as `RoomLive` / `basic-chat-poc.md`
  "Realtime inserts each message exactly once per client"). Disable composer +
  show "thinking" until the assistant's `{:new_guide_message, msg}` arrives
  (`send_user_message/2` broadcasts that same tag for the `:user` message and
  the `:assistant` reply; there is no separate `{:assistant_reply, _}` event).
- `handle_info({:new_guide_message, msg}, socket)`: `stream_insert(:guide_messages, msg, at: -1)`. Re-enable the composer when the message's `role` is `:assistant` (the reply landed); a `:user` broadcast leaves "thinking" on.

> Decision: `send_user_message/2` runs the LLM call **inline** in the LiveView
> process (not a separate Task/GenServer) for this POC — simplest, and a single
> user's guide is low-traffic. If latency becomes an issue, move the LLM call to
> a `Task` and broadcast the assistant message on completion (deferred; see
> Open questions).

### PubSub topic

- `"guide:user:<user_id>"` — per-user. Only the user is a member of their guide
  conversation, so only their own open `GuideLive` subscribes. (No multi-client
  fan-out concerns beyond the same user in two tabs — the single-insert rule
  covers it.)

### Seeds

`seeds.exs` gains, after the chat seeds:

1. `Sona.Guide.ensure_conversation/1` for the seeded users (Alice at least;
   optionally Bob/Charlie).
2. **Hardcoded proactive guide message** (role `:assistant`) inserted directly
   via `Sona.Guide.seed_proactive_message/2` — `seed_proactive_message/2`
   takes `(%User{}, body)` and **re-fetches the conversation internally**
   (`ensure_conversation/1` is idempotent, so the row from step 1 is reused),
   then inserts the `:assistant` message against it. No `:guide_target` or
   `%GuideConversation{}` argument is passed by seeds. Body is a hand-written
   pre-shift message that references the injected shift/overtime/demand data
   shape. This proves the full data→prompt shape without needing the LLM at
   seed time.
3. (Optional) one seeded `:user` follow-up + `:assistant` reply to demonstrate
   the two-way history rendering.
4. Print the guide route in the seed summary.

No `ANTHROPIC_API_KEY` is required to run seeds.

---

## Implementation notes

### Dependency

- Add `{:req_llm, "~> 1.0"}` to `mix.exs` `deps/0` (after `{:req, "~> 0.5"}`).
  `req_llm` builds on `req` (already a dep) and Finch (transitively via
  Phoenix/Bandit). Run `mix deps.get`.
- `req_llm` is a compile-time + runtime dep; no `application.ex` child needed.

### Config

- `config/runtime.exs` (prod): read `ANTHROPIC_API_KEY` and set
  `config :req_llm, :anthropic_api_key, System.fetch_env!("ANTHROPIC_API_KEY")`
  (or rely on req_llm's env auto-load). Only **require** it in prod.
- `config/dev.exs` (dev): the LLM impl is left as the
  `Sona.Guide.LLM.Anthropic` default (no `:guide_llm_impl` override needed —
  `impl/0`'s default arg covers it). Document `export ANTHROPIC_API_KEY=...`
  for dev runs; seeds do not require it. Optionally pin an explicit
  `config :sona, :guide_llm_impl, Sona.Guide.LLM.Anthropic` here so the dev
  behaviour is documented rather than implicit.
- `config/test.exs`: `config :sona, :guide_llm_impl, Sona.Guide.LLM.Stub`
  (stub in `test/support/`), and `config :sona, :guide_model,
  "anthropic:claude-3-5-haiku-20241022"`.
- Keep `:req` as the HTTP client (AGENTS.md); `req_llm` is the LLM layer on top
  — no `:httpoison` / `:tesla` / `:httpc`.

### req_llm call shape

- Prefer `ReqLLM.generate_text/3` with the `system_prompt:` option rather than
  embedding a `{:system, ...}` tuple in the messages list — verify the exact
  option/key req_llm expects against the installed version when implementing
  (the docs show `system_prompt:` as a supported option). If `system_prompt:`
  is unavailable in the pinned version, pass a leading system message via
  `ReqLLM.Context.system/1`.
- Model string via config (`:guide_model`), default
  `"anthropic:claude-3-5-haiku-20241022"` (cheap/fast for a POC follow-up
  loop; can be bumped to `claude-3-5-sonnet` via config without code
  changes). Confirm the exact id against the installed `req_llm`/`llm_db`
  version when implementing.
- `history` is built from `list_guide_messages/1` mapped to
  `%{role: role, content: body}` (roles already `:user`/`:assistant` — req_llm
  friendly). It **includes the seeded proactive `:assistant` message** as the
  first assistant turn — do not filter it out; without it the LLM has no
  record of what it pre-emptively told the user on the first follow-up.
- **Streaming**: use non-streaming `generate_text/3` for this POC (complete
  reply rendered at once). Token streaming to the browser is out of scope
  (would need `stream_text/3` + a hook + `push_event`; deferred). The
  "thinking" indicator is the UX bridge.

### Migration

- One migration: `*_create_guide_tables.exs` creating `guide_conversations` and
  `guide_messages` as above. Use `mix ecto.gen.migration create_guide_tables`.
- `guide_conversations.user_id` has a `unique` index (one conversation per
  user); `guide_messages(conversation_id, inserted_at)` index for ordered
  history fetch.

### Context (`Sona.Guide`) public API

- `ensure_conversation(%User{})` — get_or_create the user's guide conversation
  (rescue unique constraint, re-fetch). Paired with
  `unique_index(:guide_conversations, [:user_id])`.
- `list_messages(%User{} | %GuideConversation{})` — last N `guide_messages`,
  oldest→newest, `preload` nothing (no user association on guide messages).
- `latest_guide_summary(%User{})` — `nil` or `%{teaser: String.t(),
  inserted_at: DateTime}` for the Inbox Guide section.
- `send_user_message(%User{}, text)` — insert `:user` message → broadcast →
  call `Sona.Guide.LLM.impl().reply/3` with the rebuilt system prompt +
  history → insert `:assistant` message → broadcast. Returns
  `{:ok, assistant_msg}` / `{:error, reason}`.
- `seed_proactive_message(%User{}, body)` — used by seeds to insert the
  hardcoded `:assistant` proactive message (no LLM call). **Re-fetches the
  conversation internally** via `ensure_conversation/1`, so callers pass only
  `%User{}` + body; no `%GuideConversation{}` argument.
- `subscribe_guide(%User{})`.
- All APIs company-scoped (filter by `user.company_id`; reject mismatched
  conversation lookups).

### LiveView tests

- `GuideLive`: open `/guide`; see seeded proactive message (guide bubble);
  submit follow-up via `render_submit/2` on `#guide-compose-form`; assert the
  assistant reply (stub) appears as a new guide bubble; assert single insert
  per client; assert composer disabled state handled; assert error path when
  stub returns `{:error, _}` (flash + retained input).
- `InboxLive`: assert the Guide **section** is present and clearly separated
  from the Chats list (assert on a dedicated `#guide-section` element, not just
  a room row); assert the teaser reflects the latest guide message; assert
  `<.link navigate={~p"/guide"}>` present.
- No network: stub `Sona.Guide.LLM.Stub` returns a fixed reply string (and an
  error variant for the error test).

### Context tests

- `Sona.Guide` (DataCase): `ensure_conversation/1` idempotent (concurrent calls
  → one row, rescue unique constraint); `send_user_message/2` happy path
  inserts a `:user` + `:assistant` message and broadcasts both; error path
  inserts only the `:user` message (or rolls back per decision) and returns
  `{:error, _}`; company scoping — a user from company B cannot read/company-
  scope another company's guide.
- `Sona.Guide.Prompt.build/2`: returns a string containing the injected
  previous/upcoming shifts, overtime, and demand data (assert presence of key
  markers) — pure function, no network.

### Styling

- The Guide section on `/chats` and the Guide header/bubbles in `GuideLive`
  must read as **distinct from chats** (different accent / icon / label
  "Sona Guide"). This plan intentionally stays light on exact palette — defer
  concrete tokens to the styling issues (010–014 govern the daisyUI Sona theme).
  The Guide UI should use the **same** daisyUI semantic tokens (`btn`,
  `bg-base-*`, `text-base-content`) so the 010–014 retheme picks it up
  automatically. Use `<.icon name="hero-sparkles" .../>` (or similar) for the
  guide avatar to distinguish it from a coworker's initials bubble.
- Keep AGENTS.md: only `app.css`/`app.js` bundled; no `<script>` in HEEx; no
  `@apply`; Tailwind v4.

### Files to create / touch

| Path | Role |
|---|---|
| `mix.exs` | add `{:req_llm, "~> 1.0"}` |
| `config/runtime.exs` | prod `ANTHROPIC_API_KEY` → `:req_llm` |
| `config/dev.exs` | document/export `ANTHROPIC_API_KEY`; optionally pin `:guide_llm_impl` |
| `config/test.exs` | `:guide_llm_impl` stub, `:guide_model` |
| `priv/repo/migrations/*_create_guide_tables.exs` | schema |
| `lib/sona/guide.ex` | context (conversations + messages + send) |
| `lib/sona/guide/conversation.ex` | `GuideConversation` schema |
| `lib/sona/guide/message.ex` | `GuideMessage` schema (`:user` / `:assistant`) |
| `lib/sona/guide/llm.ex` | behaviour + `impl/0` |
| `lib/sona/guide/llm/anthropic.ex` | default `req_llm` impl |
| `lib/sona/guide/prompt.ex` | system prompt builder from `ShiftData` |
| `lib/sona/guide/shift_data.ex` | hardcoded temporary shift/overtime/demand |
| `lib/sona_web/router.ex` | add `live "/guide", GuideLive` |
| `lib/sona_web/live/guide_live.ex` | new chat-style guide LiveView |
| `lib/sona_web/live/guide_live.html.heex` | guide template |
| `lib/sona_web/live/inbox_live.ex` | add Guide section fetch |
| `lib/sona_web/live/inbox_live.html.heex` | render Guide section (separate from chats) |
| `priv/repo/seeds.exs` | `ensure_conversation` + hardcoded proactive message |
| `test/support/guide_llm_stub.ex` | `Sona.Guide.LLM.Stub` |
| `test/sona/guide_test.exs` | context tests |
| `test/sona/guide/prompt_test.exs` | prompt builder tests |
| `test/sona_web/live/guide_live_test.exs` | LiveView tests |
| `test/sona_web/live/inbox_live_test.exs` | extend with Guide section assertions |

---

## Acceptance criteria / definition of done

- [ ] `/chats` shows a **Guide section** that is visually and structurally
      separate from the Chats room list (assertable via a dedicated element id
      like `#guide-section`, not just another room row)
- [ ] Tapping the Guide entry opens `/guide` with the AI guide conversation
- [ ] Opening `/guide` on a user with **no guide conversation yet**
      auto-ensures the conversation on mount (renders the empty state, no
      "Set up" gate); the conversation row exists before any message is sent
- [ ] `/guide` renders a chat-style interface (scrollable messages + sticky
      composer), mobile-first, starting with `<Layouts.app ...>` and flowing
      `current_scope`
- [ ] The guide's messages are visually distinct from a coworker (guide name
      + icon/accent), so it never reads as a human chat
- [ ] Seeds insert a **hardcoded proactive pre-shift guide message** that
      references the previous/upcoming shifts, overtime, and demand data
      shape — **without** requiring `ANTHROPIC_API_KEY`
- [ ] Re-opening `/guide` restores the full guide history (proactive + exchanges)
- [ ] User can send a follow-up; the app calls the LLM via `req_llm` and the
      assistant reply appears in the conversation, with the prior history as
      context
- [ ] Reply loop is **wired through the `Sona.Guide.LLM` behaviour**; dev/prod
      uses the Anthropic `req_llm` impl, tests use a stub (no network)
- [ ] Each message is inserted exactly once per client (sender does not insert
      locally; broadcast drives the insert), consistent with `basic-chat-poc.md`
- [ ] Guide conversations are company-scoped: a user only ever sees their own;
      the context APIs filter by `user.company_id`
- [ ] Guide conversation is one-per-user (unique index); `ensure_conversation/1`
      is idempotent under concurrent calls
- [ ] **No new tables for shift/overtime/demand data** — those are hardcoded in
      `Sona.Guide.ShiftData` and passed into the prompt manually
- [ ] Public `Sona.Guide` functions tested; `Sona.Guide.Prompt.build/2` tested
      (asserts the injected data markers are present); LiveView flows covered
      with element assertions; `Sona.Guide.LLM.Stub` makes tests network-free
- [ ] `mix precommit` passes (compile, deps.unlock --unused, format, credo
      --strict, test)
- [ ] `req_llm` added as a dep; no `:httpoison` / `:tesla` / `:httpc` introduced

---

## Open questions

1. **LLM call placement (inline vs async Task).** This plan calls the LLM
   inline in the LiveView process for simplicity. If follow-up latency is
   noticeable in practice, move the LLM call to a `Task` and broadcast the
   assistant message on completion — minor refactor, deferred until observed.
2. **req_llm `system_prompt:` option vs leading system message.** The exact
   option/key req_llm expects may differ across the pinned version. Confirm
   against the installed `req_llm` when implementing; prefer the `system_prompt:`
   option, fall back to `ReqLLM.Context.system/1`.
3. **Model choice.** Plan defaults to `anthropic:claude-3-5-haiku-20241022` via
   config for cost/speed in a POC; bump to `claude-3-5-sonnet` if reply quality
   is insufficient. The dated form is used because the bare
   `anthropic:claude-3-5-haiku` is **not** a confirmed LLMDB catalog id —
   confirm the exact id against the installed `req_llm`/`llm_db` version when
   implementing. Config-driven, no code change.
4. **Proactive message source of truth.** This POC hardcodes the proactive
   message in seeds. When we later generate it with the LLM, decide whether to
   store the generated body as the seed-style `:assistant` message (yes — same
   table) and whether to store a copy of the **prompt** that produced it for
   debug/repro (probably as a separate `guide_prompt_logs` table later, not in
   `guide_messages`).
5. **Automation trigger.** A real scheduler (Quantum / Oban) that fires a
   guide message before each shift is explicitly **deferred**. It needs real
   shift data (a `shifts` table + ingestion), which is a separate plan. The
   `Sona.Guide.Prompt` + `Sona.Guide.LLM` seams built here are designed so
   that automation can call them unchanged.
6. **Multi-tab insert-once.** A single user with two tabs on `/guide` will get
   each message inserted once per tab via the broadcast round-trip (same as
   `RoomLive`). Verify in tests if we want to assert the multi-tab case
   explicitly; the single-insert rule already covers it.
7. **Guide section placement on `/chats`.** Plan says "clearly separate,
      below or in a distinct region from the chats list." Final layout (above
      vs below the chats list, card vs banner) is a styling call — defer
      concrete treatment to issues 010–014 styling pass; this plan only
      requires a distinct `#guide-section` element + guide icon/name.