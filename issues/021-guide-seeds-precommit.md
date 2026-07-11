---
id: 021
title: Guide seeds (hardcoded proactive message) + whole-slice precommit gate
status: todo
created: 2026-07-11
depends_on: [018, 019, 020]
---

## Goal
Wire the AI shift guide into `seeds.exs` so running seeds produces a demo guide conversation with a **hardcoded proactive pre-shift message** (no `ANTHROPIC_API_KEY` required), proving the data→prompt shape end-to-end, then close the slice with `mix precommit` green across the whole feature.

## Context
See `plans/ai-shift-guide.md` sections "Seeds", "Files to create / touch", and "Acceptance criteria / definition of done".

Seeds (`seeds.exs`) gains, after the existing chat seeds:
1. `Sona.Guide.ensure_conversation/1` for the seeded users (Alice at least; optionally Bob/Charlie).
2. **Hardcoded proactive guide message** (role `:assistant`) inserted directly via `Sona.Guide.seed_proactive_message/2` — `seed_proactive_message/2` takes `(%User{}, body)` and **re-fetches the conversation internally** (`ensure_conversation/1` is idempotent, so the row from step 1 is reused), then inserts the `:assistant` message against it. No `:guide_target` or `%GuideConversation{}` argument is passed by seeds. Body is a hand-written pre-shift message that references the injected shift/overtime/demand data shape. This proves the full data→prompt shape without the LLM at seed time.
3. (Optional) one seeded `:user` follow-up + `:assistant` reply to demonstrate the two-way history rendering.
4. Print the guide route in the seed summary.

No `ANTHROPIC_API_KEY` is required to run seeds.

Critical constraints (plan + `AGENTS.md`):
- `seed_proactive_message/2` makes **no** LLM call and invokes **no** `Prompt.build/2` — it is a hand-written stand-in shaped like what the prompt+LLM would return.
- `import Ecto.Query` already present in `seeds.exs`; keep it.
- `mix precommit` is the done-state gate (compile, deps.unlock --unused, format, credo --strict, test).
- Whole-slice acceptance (from the plan's definition of done) is verified here as the final gate — see criteria below.

Tools: `mix setup` (migrate + seeds) must run cleanly without a key.

## Acceptance criteria
- [ ] `seeds.exs` calls `Sona.Guide.ensure_conversation/1` for the seeded users (Alice at least; optionally Bob/Charlie)
- [ ] `seeds.exs` inserts a **hardcoded proactive `:assistant` pre-shift guide message** via `Sona.Guide.seed_proactive_message/2`, whose body references the previous/upcoming shifts, overtime, and demand data shape from `Sona.Guide.ShiftData`
- [ ] `seed_proactive_message/2` is called with only `(%User{}, body)` — no `%GuideConversation{}` argument
- [ ] `seed_proactive_message/2` makes **no** LLM call (no `ANTHROPIC_API_KEY`) and invokes **no** `Prompt.build/2`
- [ ] (Optional) one seeded `:user` follow-up + `:assistant` reply demonstrates the two-way history rendering
- [ ] `mix setup` (migrate + seeds) runs cleanly **without** `ANTHROPIC_API_KEY` set
- [ ] The seed summary prints the `/guide` route
- [ ] `/chats` shows a visually/structurally separate Guide section (`#guide-section`); Inbox InboxLive teaser reflects the latest seeded guide message
- [ ] `/guide` renders the seeded proactive guide message on load and restores full guide history on re-open
- [ ] No new tables for shift/overtime/demand data — those remain hardcoded in `Sona.Guide.ShiftData`
- [ ] `req_llm` is the LLM layer; no `:httpoison` / `:tesla` / `:httpc` introduced (`rg` confirms)
- [ ] `mix precommit` passes (compile, deps.unlock --unused, format, credo --strict, test) across the whole slice
- [ ] Full test suite green; LiveView flows use element assertions and `Sona.Guide.LLM.Stub` (no network)

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Seeds", "Acceptance criteria / definition of done", "Files to create / touch"). Integration/closing issue for the slice, mirroring the prior 009 (layout + seeds + precommit) pattern. Depends on the context (018), `GuideLive` (019), and the Inbox Guide section (020); the proactive-message source-of-truth and automation-trigger open questions are intentionally out of scope (deferred per the plan).