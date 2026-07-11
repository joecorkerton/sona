---
id: 017
title: Guide prompt builder + ShiftData (hardcoded temporary shift/overtime/demand)
status: todo
created: 2026-07-11
depends_on: []
---

## Goal
Build two pure, network-free modules that shape the data injected into the LLM: `Sona.Guide.Prompt` (a single system prompt string built from a `%User{}` + shift data map) and `Sona.Guide.ShiftData` (hardcoded sample previous/upcoming shifts, overtime, and demand modelling for the seeded site). No persistence, no LLM call — these feed `Sona.Guide.send_user_message/2` (018).

## Context
See `plans/ai-shift-guide.md` sections "Prompt builder (`Sona.Guide.Prompt`)" and "Temporary shift data (`Sona.Guide.ShiftData`)".

Key constraints (plan + `AGENTS.md`):
- `Sona.Guide.Prompt.build(%User{}, shift_data)` returns **one string**: persona + goal + the injected data + output rules. The user explicitly asked for "one prompt that has the data injected into the prompt, which gets sent to the LLM for the initial message."
- The data shape is defined but the data itself is **temporary/hardcoded** for this POC — no `shifts` / `overtime` / `demand` tables.
- `Sona.Guide.ShiftData.for(%User{})` returns a map shaped like:
  ```
  %{
    previous_shifts: [...],   # last few shifts (role, start, end, notes)
    upcoming_shifts: [...],   # the shift(s) the guide is prepping them for
    overtime: [...],          # overtime hours / context
    demand: %{...},           # demand modelling for the site
    site: user.company
  }
  ```
- Hardcoded values for the seeded users (Alice/Bob/Charlie from `seeds.exs`).
- **Only the LLM path uses the prompt builder.** The seeded proactive message (018/021) is a hand-written stand-in shaped like what the prompt+LLM would return — `seed_proactive_message/2` makes no LLM call and invokes **no** `Prompt.build/2`. `Prompt.build/2` is exercised only on follow-up replies.

Files to create:
- `lib/sona/guide/prompt.ex` — `Sona.Guide.Prompt.build/2`
- `lib/sona/guide/shift_data.ex` — `Sona.Guide.ShiftData.for/1`
- `test/sona/guide/prompt_test.exs` — pure-function tests

This issue has no deps: it touches no schema, no LLM, no LiveView. It is consumed by the context's `send_user_message/2` in 018, so 018 depends on it.

## Acceptance criteria
- [ ] `Sona.Guide.ShiftData.for(%User{})` returns a map with the keys `previous_shifts`, `upcoming_shifts`, `overtime`, `demand`, and `site` (the user's `%Company{}`); values are hardcoded sample data for the seeded users (Alice/Bob/Charlie)
- [ ] `Sona.Guide.Prompt.build(%User{}, shift_data)` returns a single string
- [ ] The returned prompt string contains identifiable markers for the injected previous shifts, upcoming shifts, overtime, and demand data (assert presence in `prompt_test.exs`)
- [ ] The prompt establishes a persona/goal for the guide and output rules for the reply
- [ ] `Sona.Guide.Prompt.build/2` is a pure function — no network, no Repo, no LLM call
- [ ] `Sona.Guide.ShiftData.for/1` is pure (no Repo/network); reads only `user.company`
- [ ] `test/sona/guide/prompt_test.exs` asserts the injected-data markers are present in the built string; tests pass without `ANTHROPIC_API_KEY`
- [ ] `mix credo --strict` clean for the new modules

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("Prompt builder", "Temporary shift data"). Pure-function issue, no deps, so it can be built/verified in isolation before the context (018) wires it into `send_user_message/2`.