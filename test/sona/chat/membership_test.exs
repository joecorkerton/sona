defmodule Sona.Chat.MembershipTest do
  use Sona.DataCase, async: true

  alias Sona.Accounts.{Company, User}
  alias Sona.Chat.{Membership, Room}

  describe "changeset/2" do
    test "inserting a membership struct works" do
      company = Repo.insert!(%Company{name: "Test", invite_token: "tok"})
      user = Repo.insert!(%User{company_id: company.id, username: "alice", display_name: "Alice"})
      room = Repo.insert!(%Room{company_id: company.id, type: :group, name: "General"})

      assert {:ok, _} = Repo.insert(%Membership{room_id: room.id, user_id: user.id})
    end

    test "duplicate membership violates unique constraint" do
      company = Repo.insert!(%Company{name: "Test", invite_token: "tok"})
      user = Repo.insert!(%User{company_id: company.id, username: "alice", display_name: "Alice"})
      room = Repo.insert!(%Room{company_id: company.id, type: :group, name: "General"})

      Repo.insert!(%Membership{room_id: room.id, user_id: user.id})

      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%Membership{room_id: room.id, user_id: user.id})
      end
    end
  end
end
