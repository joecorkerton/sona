defmodule Sona.Guide.LLM.Stub do
  @moduledoc """
  Network-free stub implementation of `Sona.Guide.LLM` for testing.

  Returns a fixed reply string by default. To force an error response in a
  test, set `Application.put_env(:sona, :guide_llm_stub_should_error, true)`
  before calling `reply/3`. Reset afterwards.
  """

  @behaviour Sona.Guide.LLM

  @impl true
  def reply(_system_prompt, _history, _user_text) do
    if Application.get_env(:sona, :guide_llm_stub_should_error, false) do
      {:error, :stub_forced_error}
    else
      {:ok, "This is a stub reply from the AI Guide."}
    end
  end
end
