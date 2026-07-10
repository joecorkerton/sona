defmodule SonaWeb.NewMessageLive do
  use SonaWeb, :live_view

  alias Sona.Chats

  @form_id "new-message-form"
  @form_name :message

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    users =
      current_user.company
      |> Chats.list_company_users()
      |> Enum.reject(&(&1.id == current_user.id))
      |> Enum.sort_by(& &1.username)

    options = Enum.map(users, &{&1.username, &1.id})

    socket =
      socket
      |> assign(:page_title, "New message")
      |> assign(:users, users)
      |> assign(:options, options)
      |> assign_form()

    {:ok, socket}
  end

  @impl true
  def handle_event("create", params, socket) do
    user_id = get_user_id(params)

    case Enum.find(socket.assigns.users, &(&1.id == user_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Please select a coworker.")}

      other_user ->
        case Chats.find_or_create_direct_room(socket.assigns.current_user, other_user) do
          {:ok, room} ->
            {:noreply, push_navigate(socket, to: ~p"/chats/#{room.id}")}

          {:error, :self} ->
            {:noreply, put_flash(socket, :error, "You cannot message yourself.")}

          {:error, :cross_company} ->
            {:noreply, put_flash(socket, :error, "Cannot message outside your company.")}
        end
    end
  end

  defp assign_form(socket) do
    assign(socket, :form, to_form(%{"user_id" => ""}, id: @form_id, as: @form_name))
  end

  defp get_user_id(params) do
    get_in(params, ["message", "user_id"]) || params["user_id"] || ""
  end
end
