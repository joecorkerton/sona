---
id: 009
title: Layout polish, seeds, precommit
status: todo
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
- [ ] `Layouts.app` shell shows Sona, current company name, and current username; stock marketing nav removed
- [ ] `<.flash_group>` only in `Layouts` (not elsewhere)
- [ ] `seeds.exs` creates a demo company with a fixed invite token (e.g. `demo-hotel`), a few users, General + one extra group, and sample messages
- [ ] `seeds.exs` uses the `create_company/1` `:invite_token` override to pin the token
- [ ] `seeds.exs` imports `Ecto.Query`
- [ ] `mix setup` (migrate + seeds) runs cleanly
- [ ] `mix precommit` passes (format + lint + tests)
- [ ] Phone-width manual pass (~390px): inbox + chat usable
- [ ] Full test suite green