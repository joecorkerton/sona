defmodule SonaWeb.RoomLive do
  use SonaWeb, :live_view

  alias Sona.Chat.{Membership, Room}
  alias Sona.Chats
  alias Sona.Repo

  @impl true
  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      case resolve_room(params, current_user) do
        {:ok, room} -> assign_room(socket, room)
        :error -> redirect(socket, to: "/chats")
      end

    {:ok, socket}
  end

  defp resolve_room(params, current_user) do
    with {:ok, room_id} <- Ecto.UUID.cast(params["id"]),
         %Room{} = room <- Repo.get(Room, room_id),
         :ok <- check_room_access(room, current_user) do
      {:ok, Repo.preload(room, memberships: [:user])}
    else
      _ -> :error
    end
  end

  defp check_room_access(room, current_user) do
    cond do
      room.company_id != current_user.company_id -> :error
      is_nil(Repo.get_by(Membership, room_id: room.id, user_id: current_user.id)) -> :error
      true -> :ok
    end
  end

  defp assign_room(socket, room) do
    current_user = socket.assigns.current_user
    messages = Chats.list_messages(room)

    socket
    |> assign(:room, room)
    |> assign(:header_name, get_header_name(room, current_user))
    |> assign(:message_count, length(messages))
    |> assign(:current_user_id, current_user.id)
    |> stream(:messages, messages, reset: true)
    |> assign_form()
    |> maybe_subscribe(room)
  end

  defp maybe_subscribe(socket, room) do
    if connected?(socket), do: Chats.subscribe_room(room)
    socket
  end

  @impl true
  def handle_event("send", %{"body" => body}, socket) do
    body = String.trim(body || "")

    if body != "" do
      Chats.send_message(socket.assigns.room, socket.assigns.current_user, %{body: body})
    end

    {:noreply, assign_form(socket)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    socket =
      socket
      |> stream_insert(:messages, message, at: -1)
      |> assign(:message_count, socket.assigns.message_count + 1)

    {:noreply, socket}
  end

  defp assign_form(socket) do
    assign(socket, :form, to_form(%{}, id: "compose-form"))
  end

  defp get_header_name(room, current_user) do
    case room.type do
      :group ->
        room.name || "Group"

      :direct ->
        other = Enum.find(room.memberships, fn m -> m.user_id != current_user.id end)

        if other, do: other.user.display_name, else: "Chat"
    end
  end
end
