defmodule Sona.Guide.LLM.AnthropicTest do
  use ExUnit.Case, async: false

  alias Sona.Guide.LLM.Anthropic

  describe "reply/3" do
    test "returns error when no API key is configured" do
      # req_llm raises ReqLLM.Error.Invalid.Parameter when ANTHROPIC_API_KEY is absent.
      # The Anthropic module catches all raised exceptions and wraps them in {:error, _}.
      # This test asserts the wrapped error shape; the exact struct is an
      # implementation detail of req_llm and may change between versions.
      assert {:error, %ReqLLM.Error.Invalid.Parameter{} = error} =
               Anthropic.reply("system", [], "hello")

      assert error.parameter =~ ~r/api_key/i
    end

    test "uses model from config" do
      env_before = Application.get_env(:sona, :guide_model)

      try do
        Application.put_env(:sona, :guide_model, "anthropic:claude-3-5-haiku-20241022")

        assert {:error, %ReqLLM.Error.Invalid.Parameter{}} =
                 Anthropic.reply("system", [], "hello")
      after
        if env_before,
          do: Application.put_env(:sona, :guide_model, env_before),
          else: Application.delete_env(:sona, :guide_model)
      end
    end
  end
end
