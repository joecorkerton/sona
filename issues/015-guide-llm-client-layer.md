---
id: 015
title: Guide LLM client layer (req_llm dep + behaviour + Anthropic impl + Stub + config)
status: todo
created: 2026-07-11
depends_on: []
---

## Goal
Add the `req_llm` dependency and build the `Sona.Guide.LLM` seam: a behaviour module with a config-resolved `impl/0`, a default Anthropic impl that calls `req_llm`, and a network-free test stub wired via `config/test.exs`. This gives the context (018) and LiveViews a swappable LLM client with no network in tests.

## Context
See `plans/ai-shift-guide.md` sections "LLM client (`Sona.Guide.LLM`)", "Dependency", "Config", and "req_llm call shape".

Key constraints (from the plan + `AGENTS.md`):
- Use `:req` (bundled) as the HTTP client; `req_llm` is the LLM layer on top. **Never** `:httpoison` / `:tesla` / `:httpc`.
- `Sona.Guide.LLM` behaviour exposes `@callback reply(system_prompt, history, user_text) :: {:ok, String.t()} | {:error, term()}`.
- Module resolved via config: `Sona.Guide.LLM.impl/0` returns `Application.get_env(:sona, :guide_llm_impl, Sona.Guide.LLM.Anthropic)`. Dev/prod leave `:guide_llm_impl` unset so the Anthropic default applies; `config/test.exs` sets it to `Sona.Guide.LLM.Stub`.
- Model spec is config-driven: `config :sona, :guide_model, "anthropic:claude-3-5-haiku-20241022"`. The dated form is used because the bare `anthropic:claude-3-5-haiku` is **not** a confirmed LLMDB catalog id — confirm the exact id against the installed `req_llm`/`llm_db` version when implementing and pin it in config.
- Call shape: prefer `ReqLLM.generate_text(model, messages, system_prompt: system_prompt)` (system prompt as an **option**, not a `{:system, ...}` tuple in the messages list — a 2-tuple with an atom head is not a shape `ReqLLM.Context.normalize/2` accepts). If `system_prompt:` is unavailable in the pinned version, fall back to a leading system message via `ReqLLM.Context.system/1`. Verify against the installed version when implementing.
- `history` is a list of loose maps `%{role, content}` (roles already `:user`/`:assistant`, req_llm-friendly) or `%ReqLLM.Message{}` structs — keys `ReqLLM.Context.normalize/2` accepts.
- API key for prod via `config/runtime.exs`: `config :req_llm, :anthropic_api_key, System.fetch_env!("ANTHROPIC_API_KEY")` (or rely on req_llm's env auto-load). Only **require** it in prod. Dev: document `export ANTHROPIC_API_KEY=...`. Seeds and tests never need a key.

Files to create/touch:
- `mix.exs` — add `{:req_llm, "~> 1.0"}` after `{:req, "~> 0.5"}`; `mix deps.get`.
- `lib/sona/guide/llm.ex` — behaviour module + `impl/0`.
- `lib/sona/guide/llm/anthropic.ex` — default `req_llm` impl (`@behaviour Sona.Guide.LLM`).
- `test/support/guide_llm_stub.ex` — `Sona.Guide.LLM.Stub` (`@behaviour ...`), returns a fixed reply string (and an error variant for the error test — e.g. a test-flag to toggle `{:error, _}`).
- `config/runtime.exs` — prod `ANTHROPIC_API_KEY` → `:req_llm`.
- `config/dev.exs` — document/export `ANTHROPIC_API_KEY`; optionally pin `config :sona, :guide_llm_impl, Sona.Guide.LLM.Anthropic` so dev behaviour is explicit.
- `config/test.exs` — `config :sona, :guide_llm_impl, Sona.Guide.LLM.Stub`, `config :sona, :guide_model, "anthropic:claude-3-5-haiku-20241022"`.

Note: the reply-loop integration (calling `reply/3` with rebuilt system prompt + history from persisted messages) lives in the context issue 018; this issue only delivers the swappable client seam itself.

## Acceptance criteria
- [ ] `{:req_llm, "~> 1.0"}` is in `mix.exs` deps (after `:req`), `mix deps.get` resolves it, and `mix deps.unlock --unused` stays clean
- [ ] No `:httpoison` / `:tesla` / `:httpc` references introduced anywhere (`rg` confirms)
- [ ] `lib/sona/guide/llm.ex` defines the `Sona.Guide.LLM` behaviour with `@callback reply/3` and an `impl/0` returning `Application.get_env(:sona, :guide_llm_impl, Sona.Guide.LLM.Anthropic)`
- [ ] `lib/sona/guide/llm/anthropic.ex` implements `@behaviour Sona.Guide.LLM`, calls `ReqLLM.generate_text/3` with the `system_prompt:` option (or verified fallback), reads the model from `Application.get_env(:sona, :guide_model, "anthropic:claude-3-5-haiku-20241022")`, and returns `{:ok, text}` / `{:error, term()}`
- [ ] `test/support/guide_llm_stub.ex` implements `Sona.Guide.LLM.Stub` returning a fixed reply string with an error-toggle variant — no network, no `ANTHROPIC_API_KEY` required
- [ ] `config/test.exs` sets `:guide_llm_impl` to the stub and pins `:guide_model`; `config/runtime.exs` requires `ANTHROPIC_API_KEY` only in prod; `config/dev.exs` documents the dev key
- [ ] The exact model id and `system_prompt:` option are confirmed against the installed `req_llm`/`llm_db` version and pinned in config (not invented)
- [ ] `mix compile` clean with the new dep + modules; no compile warnings
- [ ] `mix credo --strict` clean for the new modules

## Notes
- 2026-07-11: created from `plans/ai-shift-guide.md` ("LLM client", "Dependency", "Config", "req_llm call shape"). Spun out as a no-dependency foundation issue so the context (018) can rely on the seam being in place.