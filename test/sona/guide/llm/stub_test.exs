defmodule Sona.Guide.LLM.StubTest do
  use ExUnit.Case, async: false

  alias Sona.Guide.LLM.Stub

  describe "reply/3" do
    test "returns a fixed reply string" do
      assert {:ok, reply} = Stub.reply("system", [], "hello")
      assert reply == "This is a stub reply from the AI Guide."
    end

    test "returns error when stub_should_error flag is set" do
      Application.put_env(:sona, :guide_llm_stub_should_error, true)

      try do
        assert {:error, :stub_forced_error} = Stub.reply("system", [], "hello")
      after
        Application.delete_env(:sona, :guide_llm_stub_should_error)
      end
    end

    test "ignores system_prompt and history content" do
      assert {:ok, reply} = Stub.reply("Be helpful", [%{role: :user, content: "hi"}], "hello")
      assert reply == "This is a stub reply from the AI Guide."
    end
  end
end
