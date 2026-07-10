defmodule SonaWeb.NewGroupLive do
  use SonaWeb, :live_view

  alias Sona.Chat.Room
  alias Sona.Chats

  @form_id "new-group-form"
  @form_name :group

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "New group")
      |> assign_form()

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", params, socket) do
    changeset = name_changeset(params)
    {:noreply, assign(socket, form: to_form(changeset, id: @form_id, as: @form_name))}
  end

  def handle_event("save", params, socket) do
    name = get_name(params)

    case Chats.create_group_room(socket.assigns.current_user, %{name: name}) do
      {:ok, room} ->
        {:noreply, push_navigate(socket, to: ~p"/chats/#{room.id}")}

      {:error, _changeset} ->
        {:noreply,
         assign(socket, form: to_form(name_changeset(params), id: @form_id, as: @form_name))}
    end
  end

  defp name_changeset(params) do
    %Room{}
    |> Room.changeset(%{"name" => get_name(params), "type" => "group"})
    |> Map.put(:action, :validate)
  end

  defp assign_form(socket) do
    assign(socket, :form, to_form(%{"name" => ""}, id: @form_id, as: @form_name))
  end

  defp get_name(params) do
    get_in(params, ["group", "name"]) || params["name"] || ""
  end
end
