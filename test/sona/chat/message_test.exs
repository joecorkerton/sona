defmodule Sona.Chat.MessageTest do
  use Sona.DataCase, async: true

  alias Sona.Chat.Message

  describe "changeset/2" do
    test "validates body is required" do
      changeset = Message.changeset(%Message{}, %{})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts a valid message" do
      changeset = Message.changeset(%Message{}, %{body: "Hello!"})
      assert changeset.valid?
    end
  end
end
