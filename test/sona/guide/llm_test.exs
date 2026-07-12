defmodule Sona.Guide.LLMTest do
  use ExUnit.Case, async: false

  alias Sona.Guide.LLM

  describe "impl/0" do
    test "defaults to Anthropic when config is not set" do
      env_before = Application.get_env(:sona, :guide_llm_impl)

      try do
        Application.delete_env(:sona, :guide_llm_impl)
        assert LLM.impl() == Sona.Guide.LLM.Anthropic
      after
        if env_before, do: Application.put_env(:sona, :guide_llm_impl, env_before)
      end
    end

    test "returns configured implementation" do
      env_before = Application.get_env(:sona, :guide_llm_impl)

      try do
        Application.put_env(:sona, :guide_llm_impl, Sona.Guide.LLM.Stub)
        assert LLM.impl() == Sona.Guide.LLM.Stub
      after
        if env_before,
          do: Application.put_env(:sona, :guide_llm_impl, env_before),
          else: Application.delete_env(:sona, :guide_llm_impl)
      end
    end
  end

  describe "reply/3" do
    test "delegates to the configured implementation (Stub)" do
      env_before = Application.get_env(:sona, :guide_llm_impl)

      try do
        Application.put_env(:sona, :guide_llm_impl, Sona.Guide.LLM.Stub)

        assert {:ok, reply} = LLM.reply("system", [], "hello")
        assert reply =~ "stub reply"
      after
        if env_before,
          do: Application.put_env(:sona, :guide_llm_impl, env_before),
          else: Application.delete_env(:sona, :guide_llm_impl)
      end
    end
  end
end
