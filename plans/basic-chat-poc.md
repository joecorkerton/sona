# Plan: Basic Chat (1-1 + Group) POC

**In-repo copy:** [`plans/basic-chat-poc.md`](../../interviews/sona/plans/basic-chat-poc.md) (canonical for the project; keep in sync when revising).

## Context

Sona is a hospitality communications POC (see `docs/task-info.md`, `docs/market-research.md`, `README.md`). Product direction: **basic expandable chat** as the spine, with belonging/AI coach later—not a full Slack clone.

This plan covers **only the first vertical**: simple 1-1 and group chat **scoped to a company**, share-link onboarding by username (no passwords), LiveView UIs, Postgres persistence, mobile-first.

The codebase is a stock Phoenix 1.8 LiveView app: empty domain (`lib/sona/`), no migrations, default home page, `Phoenix.PubSub` already started. Project rules in `AGENTS.md` (streams, forms, mobile, `mix precommit`) apply.

**Key product constraint:** Chat is for a **single company** at a time. Users belong to a company; usernames are unique **within that company** only (two different hotels can both have a user `alex`). Onboarding is via a **company invite link**.

---

## Product goals (this slice)

| In scope | Out of scope (intentionally later) |
|---|---|
| Company as tenancy boundary | Auth / passwords / email |
| Group rooms + 1-1 DMs **within a company** | Threads / replies UI |
| Company share-link → pick username → chat | Reactions, attachments, read receipts |
| Username unique per company; same company+username → same history | Cross-company chat / multi-company membership |
| Mobile-first LiveView UIs | Roles / permissions / announcement-only channels |
| Architecture that can grow into threads etc. | AI coach / belonging features |

---

## High-level user flows

### A. Create a company (manager / first user)
1. Visitor opens `/` → “Create your workplace”.
2. Enters **company name**, their **username**.
3. App creates `Company` (with invite token), creates `User` scoped to that company, creates a default group room (e.g. “General”), adds them as member, sets a **session cookie via an HTTP controller** (see “Session” below — LiveViews cannot write the session), then redirects to the app.
4. Lands in inbox/chat with a **company share link** (`/join/:token`) to send to staff.

### B. Join via company share link
1. Teammate opens `/join/:token` (company invite).
2. Sees company name; enters a **username** (unique within this company only).
3. App `get_or_create`s user by `(company_id, username)`, sets the **session cookie via an HTTP controller** (LiveViews cannot write the session — see “Session” below), then redirects/`push_navigate`s into the app.
4. Auto-joins default rooms if desired (at least “General”); redirects to inbox or General chat.
5. Re-entering the same link with the **same username** reloads that identity and history (POC “login”).

### C. Chat (within company)
1. See message history (streamed list), compose box fixed at bottom.
2. Send text → persist → PubSub broadcast → all open LiveViews in that room **each** `stream_insert` the message **exactly once**. The sender is a subscriber too, so the LiveView must **not** insert locally on send (it relies on its own broadcast round-trip) — otherwise the sender sees the message twice. Delete-by-id on edits/deletes (future) follows the same single-insert rule.
3. Own messages aligned one side; others show author name (important in groups).
4. All rooms and DMs are company-scoped; never cross companies.
5. **Self-DMs are rejected**: `find_or_create_direct_room(user, user)` returns `{:error, :self}`; the DM picker excludes the current user.

### D. Inbox + group + 1-1 (within company)
1. From room list (`/chats`), see rooms the current user is in (last activity first).
2. **New group:** name a room inside the current company. **POC membership rule: rooms live under a company and membership is explicit** — creating a group adds the creator as sole member; starting a DM adds both users; joining a company adds the user to the default “General” only. (Broadening group membership to “whole company” is deferred.)
3. **Start a DM:** pick another **company member** by username (the picker lists company members via `list_company_users/1` and excludes the current user) → find-or-create a direct room for the pair **within the company** → open chat. **Self-DM is rejected** (different user required; same `company_id` required).
4. Open any room → same chat UI as group.

### Identity model (POC)
- **Company** is the tenancy boundary; all chat data hangs off it.
- **Username is unique per company** (`unique_index(:users, [:company_id, :username])`), case-insensitive normalize (store lowercase).
- Claiming a username **within that company** = “logging in” as that person (insecure; fine for interview POC).
- Session cookie stores `user_id` (user already implies `company_id`); reloads keep identity until session clears. The cookie is **set by an HTTP controller** (a `post` after the LiveView form submit), not from inside a LiveView — LiveView sockets expose the session read-only over the WebSocket. See “Session / auth” below.
- No password; no email.
- A user row is always tied to exactly one company for this POC (no multi-company membership).

---

## Architecture

### Layering

```
┌──────────────────────────────────────────────┐
│  LiveViews (UI only: assigns, events, HEEx)  │
│  HomeLive · JoinLive · InboxLive · RoomLive  │
├──────────────────────────────────────────────┤
│  SonaWeb.UserAuth (session + on_mount)       │
├──────────────────────────────────────────────┤
│  Contexts                                    │
│  Sona.Accounts  ·  Sona.Chat                 │
│  (Companies live under Accounts or Chat;     │
│   prefer Accounts: Company + User)           │
├──────────────────────────────────────────────┤
│  Schemas + Repo (Postgres)                   │
│  Company · User · Room · Membership · Message│
├──────────────────────────────────────────────┤
│  Phoenix.PubSub  topic "chat:room:{id}"      │
└──────────────────────────────────────────────┘
```

- **All writes and queries go through contexts** (`Sona.Accounts`, `Sona.Chat`). LiveViews never touch `Repo` directly.
- **Company scoping:** every Chat API takes `%User{}` (or company) and **filters by `user.company_id`**. Never list rooms/messages across companies.
- **Realtime** is thin: after a successful `Chat.send_message/3`, broadcast `{:new_message, message}`; subscribers `stream_insert`.
- **No LiveComponents** unless a clear need appears (project preference).

### Data model

```
companies
  id              uuid PK
  name            string not null
  invite_token    string not null unique   -- share link for onboarding
  timestamps

users
  id              uuid PK
  company_id      FK companies not null
  username        string not null          -- normalized lowercase
  display_name    string (optional; default = username)
  timestamps
  unique(company_id, username)

rooms
  id              uuid PK
  company_id      FK companies not null    -- tenancy: chat stays in-company
  type            Ecto.Enum, values: [:direct, :group]   -- :direct for DMs, :group for named rooms
  name            string nullable          -- required for group; null for direct
  -- DM uniqueness: canonical sorted pair token, so A↔B and B↔A resolve to one room
  direct_token    string nullable unique   -- "direct:<lo>|<hi>" (lowercased user id pair, sorted); null for :group
  timestamps
  -- no per-room invite for v1; company invite is the share link
  -- future: room-level invites, announcement channels, etc.

memberships
  id              uuid PK
  room_id         FK rooms
  user_id         FK users
  timestamps
  unique(room_id, user_id)
  index (user_id)            -- serves list_rooms_for_user/1
  -- future: role (:member | :admin)
  -- invariant (app-enforced): user.company_id == room.company_id
  -- invariant (app-enforced): :direct rooms have exactly two memberships; :group >= 1

messages
  id              uuid PK
  room_id         FK rooms
  user_id         FK users                 -- author
  body            text not null
  parent_id       uuid FK messages nullable  -- UNUSED in UI; future threads (self-referential FK is valid in Postgres)
  timestamps
  index (room_id, inserted_at)
```

**Notes on the data model:**
- `rooms.type` uses `Ecto.Enum` (schema field `:type, Ecto.Enum, values: [:direct, :group]`), not a DB-level enum — easier to extend with future kinds (e.g. `:announcement`).
- `users.display_name` has **no DB default**; set it explicitly at insert (`username` when blank). Don’t rely on a column default to mirror another column.
- `users.username` is **normalized lowercase at insert time**; uniqueness relies on stored-normalized form (no per-query lowercasing). `get_or_create_user` must `rescue Ecto.ConstraintError` on the unique index and re-fetch, to handle concurrent same-username joins.

**Expandability without implementing threads now:**
- Nullable `parent_id` on messages: top-level stay `null`; later threads filter `where parent_id is null` vs replies.
- `rooms.type` separates DMs vs groups; later kinds (e.g. announcement) can extend.
- `memberships` is the natural place for roles later.
- `companies` is the place for future org settings, coach config, etc.
- Do **not** add reactions/attachments tables until needed.

**1-1 uniqueness (within company):** for `:direct` rooms, exactly one room per **pair** of users in the same company. Enforced by a **canonical `direct_token`** column: `"direct:" <> min(user_a.id, user_b.id) <> "|" <> max(...)`, with a `unique` index. `find_or_create_direct_room(user_a, user_b)`:
- **Rejects self-DM** (`{:error, :self}` when `user_a.id == user_b.id`).
- **Rejects cross-company** (`{:error, :cross_company}` when `company_id`s differ).
- Looks up the existing `:direct` room by `direct_token`; if found, returns it (idempotent under concurrent starts). If `Repo.insert` raises on the unique index (`Ecto.ConstraintError`), rescues and re-fetches.
This avoids the self-join-on-memberships race the original design had.

**Share tokens:** company-level only for v1. Generate with stdlib, e.g. `Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)`. Store on `companies.invite_token`. `create_company/1` **accepts an optional `:invite_token` override** so seeds/tests can pin a known token (e.g. `demo-hotel`) instead of the generated one; production callers omit it.

**Default room:** on company create, create a `:group` room named `"General"` and add the creator as member. On company join, add the new user to `"General"` so they immediately have a place to chat.

### Session / “auth”

- Session cookie stores `user_id`; user belongs to company.
- **The session cookie cannot be written from a LiveView.** The LiveView socket exposes the session **read-only** over the WebSocket, and `Phoenix.LiveView.put_session/3` does not exist. Create/join flows must **submit to an HTTP controller** (`module SonaWeb.SessionController`), which calls `Plug.Conn.put_session(conn, "user_id", user.id)` then `redirect(conn, to: ...)`. The LiveView uses `push_navigate`/`<.link navigate>` to a route that hits the controller, or a `<.form action={...} method="post"}>` POST.
  - `POST /session` → params from create-company form → `Accounts.create_company/1` then `Chat.ensure_default_room/2` → set `user_id` → redirect `/chats`.
  - `POST /join/:token/session` → params from join form → `Accounts.get_or_create_user/2` then `Chat.add_to_general/1` → set `user_id` → redirect `/chats` (or `/chats/<general_id>`).
  - `DELETE /session` (optional, for “switch identity”) → clear `user_id`.
- LiveView `on_mount {SonaWeb.UserAuth, :mount_current_user}` reads the **already-set** cookie and assigns `current_user` (preloaded with `:company`) and `current_scope` e.g. `%{user: user, company: user.company}`.
- `require_user` for inbox/chat (redirect to `/` or `/join/:token` if missing).
- **`live_session` layout:** define two `live_session` blocks in the router so `current_scope` flows per AGENTS.md:
  - `live_session :current_user, on_mount: [{UserAuth, :mount_current_user}]` wraps `/chats` and `/chats/:room_id` (and the `/` redirect-to-`/chats` case).
  - `live_session :guest, on_mount: [{UserAuth, :mount_current_user}]` wraps `/` and `/join/:token` (anonymous allowed; `current_user` may be nil).
- If a session user opens a **different** company’s invite link: for POC, **joining another company always uses the username form for that company** and the controller **overwrites** `user_id` with the new user (simplest). Optionally JoinLive shows “you’re signed in as X at Company A” first.

### LiveView surfaces (mobile-first)

| Route | LiveView | Purpose |
|---|---|---|
| `/` | `HomeLive` | Create company CTA; if session → redirect to `/chats` |
| `/join/:token` | `JoinLive` | Company invite → username form → join company |
| `/chats` | `InboxLive` | Room list + new DM / new group; show company name + invite link |
| `/chats/:room_id` | `RoomLive` | Message stream + composer |

**UI patterns (AGENTS.md):**
- Always `<Layouts.app flash={@flash} current_scope={@current_scope}>`.
- Messages: **LiveView streams** (`phx-update="stream"`), not lists; empty state via `hidden only:block`.
- Forms: `to_form/2` + unique form ids; never raw changesets in templates.
- Layout: full-height column chat (header / scrollable messages / sticky composer)—phone-first; desktop as centered max-width column.
- Use existing `<.input>`, `<.icon>`, Tailwind; prefer plain Tailwind for new chat UI.

### Realtime contract

```elixir
# Sona.Chat
def send_message(%Room{} = room, %User{} = user, attrs) do
  # assert membership + same company
  with {:ok, message} <- insert_preloaded(...) do
    # Broadcast to ALL subscribers of the room topic, INCLUDING the sender's
    # own RoomLive. The sender does NOT stream_insert locally on send — it
    # relies on receiving its own broadcast, so each client inserts exactly once.
    Phoenix.PubSub.broadcast(Sona.PubSub, topic(room.id), {:new_message, message})
    {:ok, message}
  end
end

def subscribe_room(room_id), do: Phoenix.PubSub.subscribe(Sona.PubSub, topic(room_id))
defp topic(room_id), do: "chat:room:#{room_id}"
```

`RoomLive`:
- subscribe on `connected?`,
- on `handle_event("send", ...)`: call `Chat.send_message/3`, **do not `stream_insert` here** — just clear the composer / rebind socket. The message arrives via `handle_info({:new_message, msg})` below.
- `handle_info({:new_message, msg}, socket)`: `stream_insert(socket, :messages, msg, at: -1)` and rebind.

This single-insert-per-receiver rule also makes future edit/delete (`stream_delete_by_id` / re-`stream_insert`) consistent.

### Seeds
- Seed one company (known invite token logged or fixed string like `demo-hotel`), a few users, General + one extra group, sample messages—so demos work without manual setup.

---

## Recommended approach (summary)

1. **Company-scoped Postgres domain**: companies, users (unique username per company), rooms (with canonical `direct_token` for DM uniqueness), memberships (+ `user_id` index), messages (+ nullable `parent_id`).
2. **Company invite link** is the onboarding/share path; username identity within that company—no passwords.
3. **Default “General” group** so every joiner lands in a shared chat immediately. Company create is coordinated by a single function that crosses Accounts↔Chat (see below).
4. **Thin LiveViews** over `Sona.Accounts` + `Sona.Chat`; PubSub per room; all queries company-scoped. **Sessions are written by an HTTP controller**, not LiveViews.
5. **Realtime inserts once per receiver** — sender does not insert locally; everyone (sender included) inserts on broadcast.
6. **Direct-room uniqueness** via canonical sorted-pair token + unique index; self-DM and cross-company DM rejected by the context.
7. **Future threads**: schema hook only (`parent_id`); UI stays flat.

This matches hospitality (one workplace, share link to staff phones) and keeps multi-company data isolated without global usernames.

### Cross-context coordination

To keep `Sona.Accounts` and `Sona.Chat` decoupled (so Chunks 2 and 3 stay parallel — each only depends on Chunk 1), **no context calls the other**. The **HTTP controller (`SessionController`)** orchestrates across both:
- `:create` → `Accounts.create_company/1` (returns `{company, user}`) → `Chat.ensure_default_room(company, user)` → set cookie → redirect.
- `:join`  → `Accounts.get_or_create_user(company, username)` → `Chat.add_to_general(user)` → set cookie → redirect.

This keeps Accounts owning `Company`/`User` writes and Chat owning `Room`/`Membership` writes, with the controller as the one place that sequences them. (Transactions are not guaranteed across the two calls; acceptable for POC. If atomicity is later required, a `Sona.Onboarding` coordinator context can wrap both in a `Repo.transaction`.)

---

## Critical files (to create / touch)

| Path | Role |
|---|---|
| `priv/repo/migrations/*_create_chat_tables.exs` | Schema |
| `lib/sona/accounts.ex` | Company + user identity |
| `lib/sona/accounts/company.ex` | Company schema |
| `lib/sona/accounts/user.ex` | User schema (belongs_to company) |
| `lib/sona/chat.ex` + `room.ex` / `membership.ex` / `message.ex` | Chat context |
| `lib/sona_web/user_auth.ex` | `on_mount` :mount_current_user / :require_user (read-only session) |
| `lib/sona_web/controllers/session_controller.ex` | `POST /session`, `POST /join/:token/session`, (optional) `DELETE /session` — writes the `user_id` cookie and redirects |
| `lib/sona_web/router.ex` | Routes + **two `live_session` blocks** (`:current_user` wrap `/chats*`; `:guest` wrap `/`, `/join/:token`) + controller routes |
| `lib/sona_web/live/home_live.ex` | Create company |
| `lib/sona_web/live/join_live.ex` | Company invite onboarding |
| `lib/sona_web/live/inbox_live.ex` | Room list + create/DM + show company invite |
| `lib/sona_web/live/room_live.ex` | Chat UI + streams + PubSub |
| `lib/sona_web/components/layouts.ex` | Mobile app shell |
| `priv/repo/seeds.exs` | Demo company/token/users |
| `test/sona/accounts_test.exs`, `test/sona/chat_test.exs` | Context tests |
| `test/sona_web/live/*_test.exs` | LiveView tests |

**Reuse:**
- `Sona.Repo`, `Phoenix.PubSub` (`Sona.PubSub` in `application.ex`)
- `SonaWeb.CoreComponents` (`.input`, `.icon`, `.flash`)
- `Layouts.app` / `flash_group` pattern
- `SonaWeb.ConnCase` / `DataCase` + sandbox
- Stdlib crypto for tokens; no new HTTP/time deps

---

## Work chunks (independent-ish units)

### Chunk 1 — Data model & migrations
**Goal:** Durable Postgres schema for companies + chat.  
**Depends on:** nothing  
**Deliverables:**
- Migration(s): `companies`, `users`, `rooms`, `memberships`, `messages` as above
- Unique index on `companies.invite_token`; unique on `users (company_id, username)`
- Ecto schemas + changesets (username format/length, company name, body present, room name for groups)
- Associations (`user.company`, `message.user`, `room.company`, etc.)
**Verify:** `mix ecto.migrate`; changeset tests (duplicate username in same company fails; same username in two companies succeeds)

### Chunk 2 — Accounts context + session identity
**Goal:** Company + username identity with session.  
**Depends on:** Chunk 1  
**Deliverables:**
- `create_company(attrs)` — creates Company (with `invite_token`, accept **optional `:invite_token` override** for seeds) + creator User in one transaction. Returns `{company, user}`. **Does not touch Chat** (General room is wired by the controller via `Chat.ensure_default_room/2`).
- `get_company_by_invite_token/1`
- `get_or_create_user(company, username)` — scoped uniqueness; **rescues `Ecto.ConstraintError` on the `(company_id, username)` unique index and re-fetches** to handle concurrent joins with the same username.
- `SonaWeb.UserAuth` `on_mount` only (`:mount_current_user` reads cookie + preloads `:company`; `:require_user` redirects). **Does not write the session.**
- `SonaWeb.SessionController` (`create/2` for create-company → `Accounts.create_company/1` + `Chat.ensure_default_room/2`; `join/2` for join → `Accounts.get_or_create_user/2` + `Chat.add_to_general/1`; optional `delete/2`) — uses `Plug.Conn.put_session(conn, "user_id", id)` then `redirect`. Router wires `POST /session`, `POST /join/:token/session`.
- Test helper: `log_in_user(conn, user)` sets the session cookie directly (via `Plug.Test.init_test_session`).
**Verify:** context tests for company create, join identity (concurrent same-username → one user), same username different companies; controller test that `POST /session` sets cookie and redirects to `/chats`; session mount assigns `current_user`/`current_scope`.

### Chunk 3 — Chat context (rooms, membership, messages, DMs)
**Goal:** All domain operations without UI; always company-scoped.  
**Depends on:** Chunk 1 (parallel with 2 if APIs take `%User{}` / `%Company{}`)  
**Deliverables:**
- `ensure_default_room(company, user)` — creates “General” `:group` + creator membership (called by the controller after `Accounts.create_company/1`).
- `add_to_general(user)` — adds the user as a member of the company’s General room (called by the controller after `Accounts.get_or_create_user/2` on join). **Chat does not call Accounts.**
- `create_group_room(user, attrs)` → room with `company_id`, membership for creator (creator is sole member for POC).
- `list_rooms_for_user/1` (company implied by user) — backed by the `memberships(user_id)` index.
- `list_messages(room, opts)` last N, oldest→newest.
- `send_message(room, user, attrs)` membership + same-company checks; broadcasts `{:new_message, msg}` (sender included).
- `find_or_create_direct_room(user_a, user_b)`:
  - **reject self-DM** (`{:error, :self}` if `user_a.id == user_b.id`),
  - **reject cross-company** (`{:error, :cross_company}` if different `company_id`),
  - canonical `direct_token` from sorted pair of ids, unique-index backed, **rescue `Ecto.ConstraintError` and re-fetch** on concurrent create.
- `list_company_users(company)` — **required** (not optional): the DM picker lists company members and excludes the current user.
- `subscribe_room/1` / broadcast on send.
**Verify:** context tests: cross-company DM rejection, self-DM rejection, A↔B == B↔A same room, concurrent `find_or_create_direct_room/2` (two tasks) → one room, concurrent `get_or_create_user/2` same username → one user, membership/company checks on `send_message`.

### Chunk 4 — Create company (Home LiveView)
**Goal:** First-user path that establishes company + invite link.  
**Depends on:** Chunks 2 + 3  
**Deliverables:**
- Route `/` → `HomeLive` (replace stock Phoenix page)
- Form: company name + username. On submit, **POST to `SessionController :create`** (HTTP), which calls `Accounts.create_company/1` then `Chat.ensure_default_room/2`, sets the `user_id` cookie, then redirects to `/chats`. Do **not** attempt to set the session from the LiveView.
- If already logged in → redirect to inbox
**Verify:** LiveView submit POSTs to controller; company + invite token + General room created; cookie set; redirects to `/chats`.

### Chunk 5 — Join via company share link (LiveView)
**Goal:** Staff onboarding via invite.  
**Depends on:** Chunks 2 + 3  
**Deliverables:**
- Route `/join/:token` → `JoinLive`
- Show company name; invalid token UX
- Username form → **POST to `SessionController :join`** (`POST /join/:token/session`, HTTP), which calls `Accounts.get_or_create_user/2` then `Chat.add_to_general/1`, sets the `user_id` cookie, then redirects to `/chats` or `/chats/<general_id>`. Do **not** set the session from the LiveView.
- Same username again restores same user (`get_or_create_user` returns the existing row)
**Verify:** LiveView tests (username form POSTs); second join same username loads same user/history; invalid token UX; already-logged-in joining another company overwrites session.

### Chunk 6 — Room chat LiveView (core chat + realtime)
**Goal:** Messaging experience.  
**Depends on:** Chunks 2 + 3  
**Deliverables:**
- Route `/chats/:id` → `RoomLive` (require user + membership + room.company_id match)
- Stream messages; empty state; sticky composer
- Send → `Chat.send_message/3`; **do NOT `stream_insert` locally** — clear composer and rebind socket. Message arrives via the PubSub `handle_info({:new_message, msg})` → `stream_insert` (single insert per client, sender included).
- Header: group name or other user’s name for DMs
- Mobile full-height layout
**Verify:** LiveView send/display (sender sees message **once**); two clients see each other’s messages; deny other-company room ids; non-member cannot open/send.

### Chunk 7 — Inbox / room list LiveView
**Goal:** Navigate chats; surface company invite.  
**Depends on:** Chunks 2 + 3  
**Deliverables:**
- Route `/chats` → `InboxLive`
- List user’s rooms; empty state
- Show company name + shareable invite URL (primary share affordance)
- Entry points: “New group”, “New message”
**Verify:** list after fixtures; invite URL visible

### Chunk 8 — New group + 1-1 DM flows
**Goal:** Full chat matrix within company.  
**Depends on:** Chunks 6 + 7  
**Deliverables:**
- New group form (name) → create_group_room → open room
- New DM: picker lists company members via `Chat.list_company_users/1`, **excludes the current user** → `find_or_create_direct_room/2` → open room. Reject self-DM and cross-company in the UI (disable self option; cross-company members aren’t listed).
- Both appear in inbox; messages bidirectional
**Verify:** context + LiveView: A DMs B same company (bidirectional); self-DM blocked; cross-company username not listed/cannot DM; A↔B and B↔A resolve to the same room.

### Chunk 9 — Layout polish, seeds, precommit
**Goal:** Demo-ready mobile shell and clean CI.  
**Depends on:** Chunks 4–8 mostly done  
**Deliverables:**
- `Layouts.app` shell (Sona + company name + username; drop stock marketing nav)
- Seeds: demo company, fixed invite token, users, messages
- `mix precommit` green
**Verify:** phone-width manual pass; full test suite

---

## Dependency graph

```
        [1 Data model]
           /        \
   [2 Accounts]   [3 Chat context]
           \        /
     ┌──────┴───┬───┴──────┐
     │          │          │
 [4 Home/     [5 Join]  [6 RoomLive]
  Create co.]     │         │
     │            │         │
     └──────┬─────┴────┬────┘
            │          │
         [7 Inbox]  (uses 6)
            │
         [8 Group + DM flows]
            │
         [9 Polish + seeds]
```

**Parallelism:** After Chunk 1, Chunks 2∥3. After 2+3: Chunks 4∥5∥6. Then 7 → 8 → 9.

**Thin vertical for early demo:** 1 → 2 → 3 → 4 → 5 → 6 (create company, join second browser, chat in General).

---

## Acceptance criteria (whole slice)

- [ ] User can create a **company**, get a **company share link**, and another person can join with a username unique to that company
- [ ] Same username in **two different companies** creates two separate users with separate histories
- [ ] Same username **rejoining the same company** restores the same identity and chat history
- [ ] Users land in a default **General** group and can chat in realtime
- [ ] Users can create additional group rooms and 1-1 DMs **only within their company**
- [ ] **Self-DMs are rejected**; `find_or_create_direct_room(u, u)` returns `{:error, :self}` and the picker excludes the current user
- [ ] **A↔B and B↔A resolve to a single direct room** (canonical `direct_token`); concurrent creates yield one room
- [ ] The **session cookie is written by an HTTP controller**, never from a LiveView
- [ ] **Realtime inserts each message exactly once per client** (sender does not insert locally)
- [ ] All data in Postgres; company-scoped isolation enforced in context APIs
- [ ] UIs are LiveView-only, usable on phone width and desktop
- [ ] No password/auth complexity in the critical path
- [ ] Message schema allows future threads via `parent_id` without UI
- [ ] Public context functions tested; LiveView flows covered with element assertions
- [ ] `mix precommit` passes

---

## Verification (end-to-end demo script)

1. `mix setup` (migrate + seeds)
2. Browser A: create company “Seaside Hotel”, username `manager` → note company invite URL
3. Browser B (incognito): open invite URL, username `alex` → lands in General, sends “hey team”
4. Browser A: sees message in General without refresh
5. Browser A: New message → username `alex` → DM; both exchange messages
6. Browser C: create different company “Mountain Lodge”, username `alex` → **different** empty workspace (no Seaside history)
7. Restart server; re-open as Seaside `alex` via invite + username → Seaside history intact
8. Resize ~390px: inbox + chat usable

Automated: `mix test` / `mix precommit`.

---

## Risks & deliberate non-goals

| Topic | Decision |
|---|---|
| Username squatting within company | Accept for POC |
| User in multiple companies | Not supported; one user row ↔ one company |
| Room-level invite links | Deferred; company invite is enough for v1 |
| Pagination / infinite scroll | Last N messages |
| Multi-node PubSub | Single node fine |
| Typing indicators / presence | Skip |
| Message edit/delete | Skip |
| i18n | English only |

---

## Next step after plan approval

Implement in chunk order (or parallel agents for 2∥3 and 4∥5∥6). Optionally convert chunks to `issues/` via plan-to-issues. Prefer thin vertical **1→2→3→4→5→6** so two browsers can chat in General before inbox/DM polish.
