defmodule SonaWeb.UserAuth do
  @moduledoc """
  LiveView `on_mount` hooks for authentication.

  Mounts the current user / scope from the session, and provides a hook to
  halt and redirect when a user is required.
  """
  def on_mount(:mount_current_user, _params, session, socket) do
    socket =
      case session["user_id"] do
        nil ->
          socket
          |> Phoenix.Component.assign(:current_user, nil)
          |> Phoenix.Component.assign(:current_scope, nil)

        user_id ->
          user =
            Sona.Repo.get(Sona.Accounts.User, user_id)
            |> Sona.Repo.preload(:company)

          socket
          |> Phoenix.Component.assign(:current_user, user)
          |> Phoenix.Component.assign(
            :current_scope,
            user && %{user: user, company: user.company}
          )
      end

    {:cont, socket}
  end

  def on_mount(:require_user, _params, _session, socket) do
    if socket.assigns.current_user do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: "/")}
    end
  end
end
