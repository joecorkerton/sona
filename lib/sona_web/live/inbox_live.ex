defmodule SonaWeb.InboxLive do
  use SonaWeb, :live_view

  alias Sona.Chats
  alias Sona.Repo

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    company = current_user.company

    rooms =
      current_user
      |> Chats.list_rooms_for_user()
      |> Repo.preload(memberships: [:user])
      |> Enum.map(&decorate_room(&1, current_user))

    invite_url = build_invite_url(company.invite_token)

    socket =
      socket
      |> assign(:page_title, company.name)
      |> assign(:company, company)
      |> assign(:invite_url, invite_url)
      |> assign(:invite_path, "/join/#{company.invite_token}")
      |> assign(:room_count, length(rooms))
      |> stream(:rooms, rooms, reset: true)

    {:ok, socket}
  end

  defp build_invite_url(token) do
    SonaWeb.Endpoint.url() <> "/join/" <> token
  end

  defp decorate_room(room, current_user) do
    name = room_display_name(room, current_user)

    %{
      id: room.id,
      name: name,
      initial: room_initial(name)
    }
  end

  defp room_display_name(room, current_user) do
    case room.type do
      :group -> room.name || "Group"
      :direct -> direct_display_name(room, current_user)
    end
  end

  defp direct_display_name(room, current_user) do
    other =
      Enum.find(room.memberships, fn membership -> membership.user_id != current_user.id end)

    case other && other.user do
      nil -> "Direct message"
      user -> user.display_name || user.username
    end
  end

  defp room_initial(name) do
    case String.first(name) do
      nil -> "?"
      first -> String.upcase(first)
    end
  end
end
