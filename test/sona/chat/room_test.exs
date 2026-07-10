defmodule Sona.Chat.RoomTest do
  use Sona.DataCase, async: true

  alias Sona.Chat.Room

  describe "changeset/2" do
    test "validates type is required" do
      changeset = Room.changeset(%Room{}, %{})
      assert %{type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires name for group rooms" do
      changeset = Room.changeset(%Room{}, %{type: :group})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "does not require name for direct rooms" do
      changeset = Room.changeset(%Room{}, %{type: :direct})
      assert changeset.valid?
    end
  end
end
