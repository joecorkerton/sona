defmodule SonaWeb.RoomLive do
  use SonaWeb, :live_view

  alias Sona.Chats
  alias Sona.Repo
  alias Sona.Chat.{Room, Membership}

  @impl true
  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user

    socket =
      case Ecto.UUID.cast(params["id"]) do
        :error ->
          redirect(socket, to: "/chats")

        {:ok, room_id} ->
          room = Repo.get(Room, room_id)

          cond do
            is_nil(room) ->
              redirect(socket, to: "/chats")

            room.company_id != current_user.company_id ->
              redirect(socket, to: "/chats")

            is_nil(Repo.get_by(Membership, room_id: room.id, user_id: current_user.id)) ->
              redirect(socket, to: "/chats")

            true ->
              room = Repo.preload(room, memberships: [:user])

              messages = Chats.list_messages(room)

              socket
              |> assign(:room, room)
              |> assign(:header_name, get_header_name(room, current_user))
              |> assign(:message_count, length(messages))
              |> assign(:current_user_id, current_user.id)
              |> stream(:messages, messages, reset: true)
              |> assign_form()
              |> then(fn socket ->
                if connected?(socket) do
                  Chats.subscribe_room(room)
                end

                socket
              end)
          end
      end

    {:ok, socket}
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
