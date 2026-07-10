defmodule SonaWeb.UserAuthTest do
  use SonaWeb.ConnCase

  alias Sona.Accounts
  alias SonaWeb.UserAuth

  describe "on_mount :mount_current_user" do
    test "assigns current_user and current_scope when session has user_id" do
      {:ok, {_company, user}} =
        Accounts.create_company(%{name: "Test", username: "alice", invite_token: "tok"})

      conn =
        build_conn()
        |> log_in_user(user)

      session = get_session(conn)
      socket = %Phoenix.LiveView.Socket{}

      {:cont, socket} = UserAuth.on_mount(:mount_current_user, %{}, session, socket)

      assert socket.assigns.current_user.id == user.id
      assert socket.assigns.current_scope.user.id == user.id
      assert socket.assigns.current_scope.company.id == user.company_id
    end

    test "sets current_user to nil when no session" do
      socket = %Phoenix.LiveView.Socket{}
      {:cont, socket} = UserAuth.on_mount(:mount_current_user, %{}, %{}, socket)
      assert socket.assigns.current_user == nil
      assert socket.assigns.current_scope == nil
    end

    test "preloads company association" do
      {:ok, {company, user}} =
        Accounts.create_company(%{name: "Test", username: "alice", invite_token: "tok"})

      conn =
        build_conn()
        |> log_in_user(user)

      session = get_session(conn)
      socket = %Phoenix.LiveView.Socket{}

      {:cont, socket} = UserAuth.on_mount(:mount_current_user, %{}, session, socket)

      assert socket.assigns.current_user.company.id == company.id
      assert Ecto.assoc_loaded?(socket.assigns.current_user.company)
    end
  end

  describe "on_mount :require_user" do
    test "continues when current_user is set" do
      socket =
        %Phoenix.LiveView.Socket{}
        |> Phoenix.Component.assign(:current_user, %{id: "test"})

      {:cont, _socket} = UserAuth.on_mount(:require_user, %{}, %{}, socket)
    end

    test "halts and redirects when current_user is nil" do
      socket =
        %Phoenix.LiveView.Socket{}
        |> Phoenix.Component.assign(:current_user, nil)

      {:halt, socket} = UserAuth.on_mount(:require_user, %{}, %{}, socket)
      assert socket.redirected == {:redirect, %{to: "/", status: 302}}
    end
  end
end
