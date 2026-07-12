defmodule Sona.Guide.LLM.Anthropic do
  @moduledoc """
  Anthropic-backed implementation of `Sona.Guide.LLM` using `req_llm`.

  Model is resolved from config key `:sona, :guide_model`, defaulting to
  `anthropic:claude-haiku-4-5-20251001`.

  The API key must be set via `ANTHROPIC_API_KEY` environment variable
  (or `config :req_llm, :anthropic_api_key` — see `ReqLLM` docs).
  """

  @behaviour Sona.Guide.LLM

  @impl true
  def reply(system_prompt, history, user_text) do
    model = model_id()
    messages = history ++ [%{role: :user, content: user_text}]

    case call_req_llm(model, messages, system_prompt) do
      {:ok, %ReqLLM.Response{} = response} ->
        case ReqLLM.Response.text(response) do
          nil -> {:error, :empty_response}
          text -> {:ok, text}
        end

      {:error, _} = error ->
        error
    end
  end

  defp call_req_llm(model, messages, system_prompt) do
    ReqLLM.generate_text(model, messages, system_prompt: system_prompt)
  rescue
    e ->
      {:error, e}
  end

  defp model_id do
    Application.get_env(:sona, :guide_model, "anthropic:claude-haiku-4-5-20251001")
  end
end
