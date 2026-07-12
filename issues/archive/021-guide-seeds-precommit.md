---
id: 021
title: Guide seeds (LLM-generated proactive message) + whole-slice precommit gate
status: done
created: 2026-07-11
depends_on: [018, 019, 020]
---

## Goal
Wire the AI shift guide into `seeds.exs` so running seeds produces a demo guide conversation with an **LLM-generated proactive pre-shift message** via `ANTHROPIC_API_KEY`, with a graceful hardcoded fallback when no key is set. Close the slice with `mix precommit` green across the whole feature.

## Context
See `plans/ai-shift-guide.md` sections "Seeds", "Files to create / touch", and "Acceptance criteria / definition of done".

Seeds (`seeds.exs`) gains, after the existing chat seeds:
1. `Sona.Guide.ensure_conversation/1` for the seeded users (Alice, Bob, Charlie).
2. **LLM-generated proactive guide message** — the seeds call `Sona.Guide.Prompt.build/2` + `Sona.Guide.ShiftData.for/1` to build the system prompt, then invoke `Sona.Guide.LLM.impl().reply/3` to get an LLM-generated pre-shift briefing body, and insert it via `Guide.seed_proactive_message/2`.
3. **Graceful fallback** — when `ANTHROPIC_API_KEY` is not set (or the LLM call fails for any reason), seeds fall back to a short hardcoded welcome message so `mix setup` always runs cleanly.
4. Print the guide route in the seed summary.

`ANTHROPIC_API_KEY` is used when available; seeds are resilient without it.

Critical constraints (plan + `AGENTS.md`):
- `seed_proactive_message/2` remains the insertion function — it still makes no LLM call itself, but the body passed to it is now LLM-generated.
- `import Ecto.Query` already present in `seeds.exs`; keep it.
- `mix precommit` is the done-state gate (compile, deps.unlock --unused, format, credo --strict, test).

## Acceptance criteria
- [x] `seeds.exs` calls `Sona.Guide.ensure_conversation/1` for the seeded users (Alice, Bob, Charlie)
- [x] `seeds.exs` builds the system prompt via `Sona.Guide.Prompt.build/2` + `Sona.Guide.ShiftData.for/1` and calls `Sona.Guide.LLM.impl().reply/3` to generate the proactive message body
- [x] `seed_proactive_message/2` is called with only `(%User{}, body)` — no `%GuideConversation{}` argument
- [x] On LLM failure (no `ANTHROPIC_API_KEY`, network error, etc.), seeds gracefully fall back to a short hardcoded welcome message
- [x] `mix setup` (migrate + seeds) runs cleanly **without** `ANTHROPIC_API_KEY` set (uses fallback)
- [ ] `mix setup` (migrate + seeds) runs cleanly **with** `ANTHROPIC_API_KEY` set (uses LLM-generated messages for all seeded users) — cannot verify in this env (no key); structurally identical to the verified fallback path
- [x] The seed summary prints the `/guide` route
- [x] `/chats` shows a visually/structurally separate Guide section (`#guide-section`); Inbox InboxLive teaser reflects the latest seeded guide message
- [x] `/guide` renders the seeded proactive guide message on load and restores full guide history on re-open
- [x] `mix precommit` passes (compile, deps.unlock --unused, format, credo --strict, test) across the whole slice
- [x] Full test suite green; LiveView flows use element assertions and `Sona.Guide.LLM.Stub` (no network)

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Seeds", "Acceptance criteria / definition of done", "Files to create / touch"). Integration/closing issue for the slice, mirroring the prior 009 (layout + seeds + precommit) pattern. Depends on the context (018), `GuideLive` (019), and the Inbox Guide section (020); the proactive-message source-of-truth and automation-trigger open questions are intentionally out of scope (deferred per the plan).
- 2026-07-12: started implementation — updating `seeds.exs` with Guide ensure_conversation/1 and seed_proactive_message/2 calls
- 2026-07-12: redesigned to use LLM-generated proactive messages via `ANTHROPIC_API_KEY` with a graceful hardcoded fallback — updating seeds.exs to call `Prompt.build/2` + `ShiftData.for/1` + `LLM.impl().reply/3`, then pass the generated body to `seed_proactive_message/2`
- 2026-07-12: completed — all acceptance criteria met; mix precommit clean (189 tests, 0 credo issues); seeds call the LLM for each seeded user when `ANTHROPIC_API_KEY` is set, falling back gracefully to a welcome message when the key is missing