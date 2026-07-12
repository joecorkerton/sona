defmodule SonaWeb.GuideLive do
  @moduledoc """
  Chat-style LiveView for the AI Shift Guide at `/guide`.

  Models `SonaWeb.RoomLive` closely, but the counterpart is the LLM rather
  than a coworker, so the surface is visually distinct (guide accent on
  assistant bubbles, "Sona Guide" header with a sparkles icon, dedicated
  Guide section in the inbox).

  `mount/3` auto-ensures the user's guide conversation so `/guide` always
  renders, even on a first visit. Messages stream in from
  `Sona.Guide.send_user_message/2` via PubSub broadcasts on
  `"guide:user:<user.id>"` (no local insert in the send handler — the
  broadcast round-trip drives the insert, single insert per client).
  """
  use SonaWeb, :live_view

  alias Sona.Guide

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    conversation = Guide.ensure_conversation(current_user)
    messages = Guide.list_messages(conversation)

    socket =
      socket
      |> assign(:page_title, "Sona Guide")
      |> assign(:message_count, length(messages))
      |> assign(:thinking, false)
      |> stream(:guide_messages, messages, reset: true)
      |> assign_form()
      |> maybe_subscribe(current_user)

    {:ok, socket}
  end

  defp maybe_subscribe(socket, current_user) do
    if connected?(socket), do: Guide.subscribe_guide(current_user)
    socket
  end

  @impl true
  def handle_event("send", %{"body" => body}, socket) do
    body = String.trim(body || "")

    socket =
      if body == "" do
        socket
      else
        case Guide.send_user_message(socket.assigns.current_user, body) do
          {:ok, _assistant_msg} ->
            # LLM call landed; thinking stays on until the assistant
            # broadcast lands in handle_info, then re-enables composer.
            assign_form(socket) |> assign(:thinking, true)

          {:error, reason} ->
            # No assistant message will arrive; re-enable composer so the
            # user can retry with their text retained in the input.
            socket
            |> put_flash(:error, format_error(reason))
            |> assign_form_with_text(body)
            |> assign(:thinking, false)
        end
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_guide_message, msg}, socket) do
    socket =
      socket
      |> stream_insert(:guide_messages, msg, at: -1)
      |> assign(:message_count, socket.assigns.message_count + 1)
      |> maybe_finish_thinking(msg)

    {:noreply, socket}
  end

  # Re-enable the composer only when the assistant reply lands; a :user
  # broadcast (the user's own message coming back through PubSub) leaves
  # "thinking" on while we wait for the LLM.
  defp maybe_finish_thinking(socket, %{role: :assistant}), do: assign(socket, :thinking, false)
  defp maybe_finish_thinking(socket, _user_msg), do: socket

  defp assign_form(socket) do
    assign(socket, :form, to_form(%{"body" => ""}, id: "guide-compose-form"))
  end

  defp assign_form_with_text(socket, text) do
    assign(socket, :form, to_form(%{"body" => text}, id: "guide-compose-form"))
  end

  defp format_error(reason) do
    "Couldn't reach the guide right now (#{inspect(reason)}). Try again in a moment."
  end
end
