---
id: 020
title: InboxLive Guide section (distinct from Chats room list)
status: done
created: 2026-07-11
depends_on: [018]
---

## Goal
Extend `InboxLive` (`/chats`) with a clearly-separated **Guide section** below (or in a distinct region from) the Chats room list: a single entry — the user's AI shift guide — showing the latest guide message teaser and a `<.link navigate={~p"/guide"}>` tap target. Visually and structurally separate, not just another row in the chats list.

## Context
See `plans/ai-shift-guide.md` sections "Product / user flows → A. Discover the Guide from `/chats`", "LiveView surfaces", and "InboxLive extension".

Flow:
1. Signed-in user opens `/chats` (InboxLive). Below the company header / invite link / chats room list, a clearly separated **"Guide" section** is shown (distinct heading + visual treatment, not just another row in the chats list).
2. The Guide section shows a single entry — the user's AI shift guide — with a short teaser of the latest guide message (e.g. "Here's how tomorrow looks…") and a tap target.
3. Tapping it opens `/guide` (019). Only one guide conversation exists per user; there is no "new guide" action.

`InboxLive` extension details (from the plan):
- Add a **Guide section** visually separated from the Chats `<section>` (separate heading like "Guide", distinct card/border treatment) — **below** the chats list or in a clearly separate region, not interleaved with room rows.
- Fetch via `Sona.Guide.latest_guide_summary/1`, which **auto-ensures** the conversation (same idempotent `ensure_conversation/1` as `GuideLive`), so it never returns `nil` for a signed-in user — the teaser is `nil`/empty only when the conversation has no messages yet (fresh user, not yet seeded). In that case the entry still links to `/guide` with a "Set up your guide" CTA; `GuideLive.mount` creates the row on open. Empty state via `hidden only:block`.

Styling: use the same daisyUI semantic tokens (`btn`, `bg-base-*`, `text-base-content`) so the 010–014 retheme picks it up; use `<.icon name="hero-sparkles" .../>` (or similar) for the guide entry so it reads as the AI guide, not a coworker's initials bubble. Final placement (above vs below the chats list, card vs banner) is a styling call deferred to the 010–014 pass — this issue only requires a distinct `#guide-section` element + guide icon/name. Keep AGENTS.md: no `<script>` in HEEx; no `@apply`; Tailwind v4.

Files to touch:
- `lib/sona_web/live/inbox_live.ex` — fetch `latest_guide_summary/1`, assign for the section
- `lib/sona_web/live/inbox_live.html.heex` — render the Guide section (separate from chats)
- `test/sona_web/live/inbox_live_test.exs` — extend with Guide section assertions

Test constraints (AGENTS.md / plan): `Phoenix.LiveViewTest` + `LazyHTML`; assert on a dedicated `#guide-section` element (not just a room row); assert the teaser reflects the latest guide message; assert `<.link navigate={~p"/guide"}>` present; assert empty-state ("Set up your guide" CTA) when no messages yet.

## Acceptance criteria
- [x] `/chats` renders a **Guide section** as a distinct element (assertable via a dedicated id, e.g. `#guide-section`), not interleaved with room rows
- [x] The Guide section has a separate heading ("Guide") and visual treatment distinct from the Chats room list
- [x] The Guide entry uses a guide icon (`<.icon name="hero-sparkles" .../>` or similar) so it does not read as a coworker's initials bubble
- [x] The Guide entry is a `<.link navigate={~p"/guide"}>` tap target (not `live_redirect`/`live_patch`)
- [x] Fetch uses `Sona.Guide.latest_guide_summary/1`; the teaser reflects the latest guide message when one exists
- [x] When the guide conversation has no messages yet (fresh, unseeded user), the entry still renders and links to `/guide` with a "Set up your guide" CTA (empty state via `hidden only:block`)
- [x] `test/sona_web/live/inbox_live_test.exs` asserts the `#guide-section` element is present and separate from the chats list, the teaser reflects the latest guide message, the `navigate={~p"/guide"}` link is present, and the empty-state CTA renders when no guide messages exist
- [x] `mix credo --strict` clean for the changed modules

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Product/user flows A", "InboxLive extension", "LiveView tests"). Depends on the context (018) for `latest_guide_summary/1`; does not depend on `GuideLive` (019) — both consume the context independently. Final Guide-section layout polish is deferred to the 010–014 styling pass.
- 2026-07-12: started implementation — extending `InboxLive` with a separate `#guide-section` driven by `Sona.Guide.latest_guide_summary/1` (auto-ensures the conversation per 018).
- 2026-07-12: InboxLive now assigns `:guide_summary` and the template renders `<section id="guide-section">` with a guide heading, `<.icon name="hero-sparkles">` avatar, teaser/empty-CTA, and `<.link navigate={~p"/guide"}>` tap target — all visually separate from the chats list.
- 2026-07-12: `test/sona_web/live/inbox_live_test.exs` extended with 8 tests covering `#guide-section` presence + heading, structural separation from `#rooms` (via LazyHTML), guide sparkles icon, `navigate={~p"/guide"}` link, teaser from latest message, multi-message ordering (with explicit `inserted_at` for determinism — see ordering note below), empty-state "Set up your guide" CTA, and `/chats` auto-ensures the conversation. All 22 InboxLive tests pass.
- 2026-07-12: **Ordering non-determinism note** — the "reflects the most recent message when there are several" test exposes that `Sona.Guide.latest_guide_summary/1` ties on `inserted_at` with a `desc: m.id` tiebreaker, which is **non-deterministic for random binary UUIDs** (autogenerated by Ecto's `:binary_id` PKs). Two messages inserted in the same `:naive_datetime` second may resolve to either one. The test inserts with explicit `inserted_at` to be deterministic. **This is a real context-module concern (issue 018 territory) and should be addressed there** — options include: switching `timestamps()` to `:naive_datetime_usec` (already supported by Postgres), adding a monotonic sequence column, or using `Ecto.Changeset.force_change/3` in `insert_message/3` to bump `inserted_at` when a same-second collision would occur. Out of scope for 020; logging here for a follow-up.
- 2026-07-12: **Route stub added** — added `live "/guide", GuideLive` to `router.ex` and a minimal `SonaWeb.GuideLive` placeholder module so the `<.link navigate={~p"/guide"}>` reference on `/chats` compiles under `--warnings-as-errors`. The placeholder renders a "Your AI shift guide is coming soon" message and will be replaced by the full chat-style implementation in issue 019. This is a minor scope extension beyond 020's original `depends_on: [018]`, but it's the smallest change that makes the verified-routes sigil work and the link functional in production. The placeholder is isolated and clearly marked as such.
- 2026-07-12: completed — all acceptance criteria met; mix precommit clean (173 tests, 0 credo issues).
- 2026-07-12: **Post-review fixes** — (1) the empty-state CTA now uses the `hidden only:block` pattern (teaser keeps `:if` so the CTA becomes the `:only-child` of its wrapper when no teaser; the wrapper `div.guide-content-row` exists for this purpose); (2) the "structurally separate from the chats list" test no longer matches serialized HTML — it now uses `has_element?/2,3` with descendant-combinator selectors (`refute has_element?(view, "#guide-section #rooms")`) and text-arg form (`refute has_element?(view, "#rooms", "Sona Guide")`). LazyHTML usage dropped from the test.