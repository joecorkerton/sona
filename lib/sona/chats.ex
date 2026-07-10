defmodule Sona.Chats do
  @moduledoc """
  Context for chat rooms, memberships, and messages.

  Handles the lifecycle of rooms (default `General` room, group rooms, and
  direct 1:1 rooms), membership of users in rooms, and posting/broadcasting
  messages over PubSub.
  """

  import Ecto.Query

  alias Sona.Accounts.User
  alias Sona.Chat.Membership
  alias Sona.Chat.Message
  alias Sona.Chat.Room
  alias Sona.Repo

  @doc """
  Creates a "General" `:group` room for the company with the creator as a member.
  Idempotent — returns the existing room if one already exists.
  """
  def ensure_default_room(company, user) do
    case Repo.get_by(Room, company_id: company.id, name: "General", type: :group) do
      nil -> create_default_room(company, user)
      room -> add_membership_and_return(room, user)
    end
  end

  defp create_default_room(company, user) do
    %Room{}
    |> Room.changeset(%{company_id: company.id, name: "General", type: :group})
    |> Repo.insert()
    |> handle_default_room_insert(company, user)
  end

  defp handle_default_room_insert({:ok, room}, _company, user) do
    add_membership_and_return(room, user)
  end

  defp handle_default_room_insert({:error, changeset}, company, user) do
    if duplicate_room_error?(changeset) do
      room = Repo.get_by!(Room, company_id: company.id, name: "General", type: :group)
      add_membership_and_return(room, user)
    else
      {:error, changeset}
    end
  end

  defp add_membership_and_return(room, user) do
    create_membership(room, user)
    {:ok, room}
  end

  @doc """
  Adds a user as a member of the company's General room.
  Returns `{:ok, membership}` or `{:error, :no_general_room}`.
  """
  def add_to_general(user) do
    case Repo.get_by(Room, company_id: user.company_id, name: "General", type: :group) do
      nil -> {:error, :no_general_room}
      room -> create_membership(room, user)
    end
  end

  @doc """
  Creates a `:group` room with the given attributes and the creator as sole member.
  """
  def create_group_room(user, attrs) do
    %Room{}
    |> Room.changeset(Map.merge(attrs, %{company_id: user.company_id, type: :group}))
    |> Repo.insert()
    |> case do
      {:ok, room} ->
        create_membership(room, user)
        {:ok, room}

      error ->
        error
    end
  end

  @doc """
  Lists rooms the user is a member of, scoped to the user's company.
  """
  def list_rooms_for_user(user) do
    member_room_ids =
      from(m in Membership, where: m.user_id == ^user.id, select: m.room_id)

    Repo.all(
      from r in Room,
        where: r.id in subquery(member_room_ids) and r.company_id == ^user.company_id,
        preload: [:memberships]
    )
  end

  @doc """
  Returns the last N messages for a room, ordered oldest→newest.
  Default limit is 50.
  """
  def list_messages(room, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    query =
      from m in Message,
        where: m.room_id == ^room.id,
        order_by: [asc: m.inserted_at, asc: m.id],
        limit: ^limit,
        preload: [:user]

    Repo.all(query)
  end

  @doc """
  Sends a message to a room. Checks that the user is a member of the room and
  belongs to the same company. On success, broadcasts `{:new_message, message}`
  to the PubSub topic `"chat:room:<room.id>"`.

  Returns `{:ok, message}`, `{:error, :not_member}`, `{:error, :cross_company}`,
  or `{:error, changeset}`.
  """
  def send_message(room, user, attrs) do
    with {:ok, _membership} <- check_membership(room, user),
         :ok <- check_same_company(room, user) do
      message =
        %Message{}
        |> Message.changeset(attrs)
        |> Ecto.Changeset.put_change(:room_id, room.id)
        |> Ecto.Changeset.put_change(:user_id, user.id)
        |> Repo.insert!()
        |> Repo.preload(:user)

      Phoenix.PubSub.broadcast(
        Sona.PubSub,
        "chat:room:#{room.id}",
        {:new_message, message}
      )

      {:ok, message}
    end
  end

  @doc """
  Finds or creates a direct room between two users.

  Returns `{:ok, room}`, `{:error, :self}`, or `{:error, :cross_company}`.
  """
  def find_or_create_direct_room(user_a, user_b) do
    cond do
      user_a.id == user_b.id ->
        {:error, :self}

      user_a.company_id != user_b.company_id ->
        {:error, :cross_company}

      true ->
        token = direct_token(user_a, user_b)

        case Repo.get_by(Room, direct_token: token) do
          nil -> create_direct_room(token, user_a, user_b)
          room -> {:ok, room}
        end
    end
  end

  @doc """
  Lists all users belonging to a company.
  """
  def list_company_users(company) do
    Repo.all(from u in User, where: u.company_id == ^company.id)
  end

  @doc """
  Subscribes the current process to the room's PubSub topic.
  """
  def subscribe_room(room) do
    Phoenix.PubSub.subscribe(Sona.PubSub, "chat:room:#{room.id}")
  end

  # --- private ---

  defp create_membership(room, user) do
    %Membership{}
    |> Membership.changeset(%{})
    |> Ecto.Changeset.put_change(:room_id, room.id)
    |> Ecto.Changeset.put_change(:user_id, user.id)
    |> Repo.insert()
    |> case do
      {:ok, membership} ->
        {:ok, membership}

      {:error, changeset} ->
        if duplicate_membership_error?(changeset) do
          {:ok, Repo.get_by!(Membership, room_id: room.id, user_id: user.id)}
        else
          {:error, changeset}
        end
    end
  end

  defp create_direct_room(token, user_a, user_b) do
    changeset =
      Room.changeset(%Room{}, %{
        company_id: user_a.company_id,
        type: :direct,
        direct_token: token
      })

    case Repo.insert(changeset) do
      {:ok, room} ->
        create_membership(room, user_a)
        create_membership(room, user_b)
        {:ok, room}

      {:error, changeset} ->
        if duplicate_token_error?(changeset) do
          {:ok, Repo.get_by!(Room, direct_token: token)}
        else
          {:error, changeset}
        end
    end
  end

  defp direct_token(user_a, user_b) do
    ids = [to_string(user_a.id), to_string(user_b.id)]
    [lo, hi] = Enum.sort(ids)
    "direct:#{String.downcase(lo)}|#{String.downcase(hi)}"
  end

  defp check_membership(room, user) do
    case Repo.get_by(Membership, room_id: room.id, user_id: user.id) do
      nil -> {:error, :not_member}
      membership -> {:ok, membership}
    end
  end

  defp check_same_company(room, user) do
    if user.company_id == room.company_id do
      :ok
    else
      {:error, :cross_company}
    end
  end

  defp duplicate_room_error?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_msg, opts}} ->
      opts[:constraint] == :unique and
        to_string(opts[:constraint_name]) == "rooms_company_id_type_name_index"
    end)
  end

  defp duplicate_membership_error?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_msg, opts}} ->
      opts[:constraint] == :unique and
        to_string(opts[:constraint_name]) == "memberships_room_id_user_id_index"
    end)
  end

  defp duplicate_token_error?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_msg, opts}} ->
      opts[:constraint] == :unique and
        to_string(opts[:constraint_name]) == "rooms_direct_token_index"
    end)
  end
end
