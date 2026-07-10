defmodule Sona.ChatsTest do
  use Sona.DataCase, async: false

  import Ecto.Query

  alias Sona.Accounts.{Company, User}
  alias Sona.Chat.{Membership, Message, Room}
  alias Sona.Chats

  setup do
    company = Repo.insert!(%Company{name: "Acme", invite_token: "abc123"})
    user = Repo.insert!(%User{company_id: company.id, username: "alice", display_name: "Alice"})
    %{company: company, user: user}
  end

  describe "ensure_default_room/2" do
    test "creates a General group room with creator membership", %{company: company, user: user} do
      assert {:ok, room} = Chats.ensure_default_room(company, user)
      assert room.name == "General"
      assert room.type == :group
      assert room.company_id == company.id

      assert Repo.get_by(Membership, room_id: room.id, user_id: user.id)
    end

    test "is idempotent", %{company: company, user: user} do
      assert {:ok, room1} = Chats.ensure_default_room(company, user)
      assert {:ok, room2} = Chats.ensure_default_room(company, user)
      assert room1.id == room2.id
    end
  end

  describe "add_to_general/1" do
    test "adds user as member of the company's General room", %{company: company, user: user} do
      {:ok, room} = Chats.ensure_default_room(company, user)

      second_user =
        Repo.insert!(%User{company_id: company.id, username: "bob", display_name: "Bob"})

      assert {:ok, _membership} = Chats.add_to_general(second_user)
      assert Repo.get_by(Membership, room_id: room.id, user_id: second_user.id)
    end

    test "returns error when no General room exists", %{company: company} do
      user = Repo.insert!(%User{company_id: company.id, username: "bob", display_name: "Bob"})
      assert {:error, :no_general_room} = Chats.add_to_general(user)
    end
  end

  describe "create_group_room/2" do
    test "creates a group room with company_id and creator as sole member", %{
      company: company,
      user: user
    } do
      assert {:ok, room} = Chats.create_group_room(user, %{name: "Random"})
      assert room.name == "Random"
      assert room.type == :group
      assert room.company_id == company.id

      assert Repo.get_by(Membership, room_id: room.id, user_id: user.id)
      assert Repo.aggregate(from(m in Membership, where: m.room_id == ^room.id), :count, :id) == 1
    end
  end

  describe "list_rooms_for_user/1" do
    test "returns user's rooms scoped to their company", %{company: company, user: user} do
      {:ok, general} = Chats.ensure_default_room(company, user)
      {:ok, group} = Chats.create_group_room(user, %{name: "Dev"})

      rooms = Chats.list_rooms_for_user(user)
      room_ids = Enum.map(rooms, & &1.id)
      assert general.id in room_ids
      assert group.id in room_ids
      assert length(rooms) == 2
    end

    test "does not include rooms from other companies", %{company: company, user: user} do
      other_company = Repo.insert!(%Company{name: "Other", invite_token: "other123"})

      other_user =
        Repo.insert!(%User{company_id: other_company.id, username: "eve", display_name: "Eve"})

      Chats.ensure_default_room(other_company, other_user)
      Chats.ensure_default_room(company, user)

      rooms = Chats.list_rooms_for_user(user)
      assert length(rooms) == 1
    end
  end

  describe "list_messages/2" do
    test "returns messages oldest→newest with default limit", %{company: company, user: user} do
      {:ok, room} = Chats.ensure_default_room(company, user)

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      insert_message(room, user, "First", NaiveDateTime.add(now, -3, :second))
      insert_message(room, user, "Second", NaiveDateTime.add(now, -2, :second))
      insert_message(room, user, "Third", NaiveDateTime.add(now, -1, :second))

      messages = Chats.list_messages(room)
      assert Enum.map(messages, & &1.body) == ["First", "Second", "Third"]
    end

    test "respects :limit option", %{company: company, user: user} do
      {:ok, room} = Chats.ensure_default_room(company, user)

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      for i <- 1..10 do
        insert_message(room, user, "Message #{i}", NaiveDateTime.add(now, -(10 - i), :second))
      end

      messages = Chats.list_messages(room, limit: 3)
      assert length(messages) == 3
      assert Enum.map(messages, & &1.body) == ["Message 1", "Message 2", "Message 3"]
    end
  end

  describe "send_message/3" do
    test "creates a message and broadcasts it", %{company: company, user: user} do
      {:ok, room} = Chats.ensure_default_room(company, user)
      Chats.subscribe_room(room)

      assert {:ok, message} = Chats.send_message(room, user, %{body: "Hello!"})
      assert message.body == "Hello!"
      assert message.user_id == user.id
      assert message.room_id == room.id

      assert_receive {:new_message, ^message}, 500
    end

    test "rejects non-members", %{company: company} do
      room = Repo.insert!(%Room{company_id: company.id, type: :group, name: "Secret"})
      user = Repo.insert!(%User{company_id: company.id, username: "eve", display_name: "Eve"})

      assert {:error, :not_member} = Chats.send_message(room, user, %{body: "Hello!"})
    end

    test "rejects cross-company users", %{company: company, user: user} do
      other_company = Repo.insert!(%Company{name: "Other", invite_token: "other123"})
      {:ok, room} = Chats.ensure_default_room(company, user)

      other_user =
        Repo.insert!(%User{company_id: other_company.id, username: "eve", display_name: "Eve"})

      Repo.insert!(%Membership{room_id: room.id, user_id: other_user.id})

      assert {:error, :cross_company} = Chats.send_message(room, other_user, %{body: "Hello!"})
    end
  end

  describe "find_or_create_direct_room/2" do
    test "rejects self-DM", %{user: user} do
      assert {:error, :self} = Chats.find_or_create_direct_room(user, user)
    end

    test "rejects cross-company", %{company: _, user: user} do
      other_company = Repo.insert!(%Company{name: "Other", invite_token: "other123"})

      other_user =
        Repo.insert!(%User{company_id: other_company.id, username: "bob", display_name: "Bob"})

      assert {:error, :cross_company} = Chats.find_or_create_direct_room(user, other_user)
    end

    test "creates a direct room with two memberships", %{company: company, user: user} do
      other = Repo.insert!(%User{company_id: company.id, username: "bob", display_name: "Bob"})

      assert {:ok, room} = Chats.find_or_create_direct_room(user, other)
      assert room.type == :direct
      assert room.company_id == company.id
      assert room.direct_token =~ "direct:"

      assert Repo.get_by(Membership, room_id: room.id, user_id: user.id)
      assert Repo.get_by(Membership, room_id: room.id, user_id: other.id)
      assert Repo.aggregate(from(m in Membership, where: m.room_id == ^room.id), :count, :id) == 2
    end

    test "A↔B and B↔A resolve to the same room", %{company: company, user: user} do
      other = Repo.insert!(%User{company_id: company.id, username: "bob", display_name: "Bob"})

      assert {:ok, room_ab} = Chats.find_or_create_direct_room(user, other)
      assert {:ok, room_ba} = Chats.find_or_create_direct_room(other, user)
      assert room_ab.id == room_ba.id
    end

    test "concurrent creates yield one room (rescues ConstraintError)", %{
      company: company,
      user: user
    } do
      other = Repo.insert!(%User{company_id: company.id, username: "bob", display_name: "Bob"})

      results =
        [1, 2]
        |> Task.async_stream(
          fn _ ->
            Chats.find_or_create_direct_room(user, other)
          end,
          timeout: :infinity
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert length(results) == 2
      room_ids = Enum.map(results, fn {:ok, r} -> r.id end) |> Enum.uniq()
      assert length(room_ids) == 1
    end
  end

  describe "list_company_users/1" do
    test "returns all users in a company", %{company: company, user: user} do
      Repo.insert!(%User{company_id: company.id, username: "bob", display_name: "Bob"})

      users = Chats.list_company_users(company)
      user_ids = Enum.map(users, & &1.id)
      assert user.id in user_ids
      assert length(users) == 2
    end

    test "does not return users from other companies", %{company: company} do
      Repo.insert!(%User{company_id: company.id, username: "carol", display_name: "Carol"})

      other_company = Repo.insert!(%Company{name: "Other", invite_token: "other123"})
      Repo.insert!(%User{company_id: other_company.id, username: "eve", display_name: "Eve"})

      assert length(Chats.list_company_users(company)) == 2
    end
  end

  describe "subscribe_room/1" do
    test "subscribes current process to room PubSub topic", %{company: company, user: user} do
      {:ok, room} = Chats.ensure_default_room(company, user)
      :ok = Chats.subscribe_room(room)

      Chats.send_message(room, user, %{body: "Ping"})
      assert_receive {:new_message, _msg}, 500
    end
  end

  defp insert_message(room, user, body, inserted_at) do
    Repo.insert!(%Message{
      room_id: room.id,
      user_id: user.id,
      body: body,
      inserted_at: inserted_at
    })
  end
end
