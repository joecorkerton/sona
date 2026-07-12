defmodule Sona.Guide.LLM do
  @moduledoc """
  Behaviour and dispatch for the LLM client used by the AI Shift Guide.

  The module resolved at runtime via `impl/0` handles the actual network call.
  Swap implementations via config:

      config :sona, :guide_llm_impl, Sona.Guide.LLM.Stub
  """

  @doc """
  Returns `{:ok, reply_text}` or `{:error, reason}`.

  - `system_prompt` — a string with the system-level instruction.
  - `history` — a list of `%{role: role, content: content}` maps with roles
    `:user` or `:assistant`.
  - `user_text` — the latest user message text.
  """
  @callback reply(system_prompt :: String.t(), history :: list(), user_text :: String.t()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  Returns the configured LLM implementation module.

      iex> Sona.Guide.LLM.impl()
      Sona.Guide.LLM.Anthropic

  Defaults to `Sona.Guide.LLM.Anthropic` when `:guide_llm_impl` is not set.
  """
  def impl do
    Application.get_env(:sona, :guide_llm_impl, Sona.Guide.LLM.Anthropic)
  end

  @doc """
  Delegates to the configured implementation's `reply/3`.
  """
  def reply(system_prompt, history, user_text) do
    impl().reply(system_prompt, history, user_text)
  end
end
