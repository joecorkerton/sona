---
id: 009
title: Layout polish, seeds, precommit
status: done
created: 2026-07-10
depends_on: [004, 005, 006, 007, 008]
---

## Goal
Demo-ready mobile shell and a clean CI gate: an app layout showing Sona + company name + username, demo seeds with a fixed invite token, and `mix precommit` green.

## Context
See `plans/basic-chat-poc.md` sections "Seeds" (line 225), "Layout" notes (lines 190–196), and "Chunk 9" (lines 371–378). Also the whole-slice acceptance criteria (lines 409–425).

Critical constraints:
- `Layouts.app` shell: Sona + company name + username; drop the stock marketing nav. `<.flash_group>` only belongs in `Layouts`.
- Seeds: demo company with a **fixed** invite token (e.g. `demo-hotel`), a few users, General + one extra group, sample messages — `create_company/1` accepts the optional `:invite_token` override for this. `import Ecto.Query` in `seeds.exs`.
- `mix precommit` green (lint + format + tests).
- Following AGENTS.md project rules: streams, `to_form/2`, mobile-first, no `@apply`, hero icon components, etc.

## Acceptance criteria
- [x] `Layouts.app` shell shows Sona, current company name, and current username; stock marketing nav removed
- [x] `<.flash_group>` only in `Layouts` (not elsewhere)
- [x] `seeds.exs` creates a demo company with a fixed invite token (e.g. `demo-hotel`), a few users, General + one extra group, and sample messages
- [x] `seeds.exs` uses the `create_company/1` `:invite_token` override to pin the token
- [x] `seeds.exs` imports `Ecto.Query`
- [x] `mix setup` (migrate + seeds) runs cleanly
- [x] `mix precommit` passes (format + lint + tests)
- [x] Phone-width manual pass (~390px): inbox + chat usable
- [x] Full test suite green

## Notes
- 2026-07-10: started implementation — updating Layouts.app shell with Sona + company name + username; writing seeds; ensuring precommit green
- 2026-07-10: Layouts.app rewritten — header shows Sona brand + company name + username when authenticated, removed stock marketing nav, kept theme toggle
- 2026-07-10: seeds.exs written — creates Demo Hotel with demo-hotel invite token, 3 users (alice/bob/charlie), General + Staff Lounge rooms with sample messages; uses create_company/1 :invite_token override; imports Ecto.Query; mix setup clean
- 2026-07-10: removed dead Phoenix stock pages (PageController, PageHTML, home.html.heex) — stray flash_group gone
- 2026-07-10: RoomLive template adjusted -mt-20→-mt-6 to match new layout py-6
- 2026-07-10: All 113 tests passing; mix precommit clean
- 2026-07-10: completed — all acceptance criteria met; mix precommit clean
