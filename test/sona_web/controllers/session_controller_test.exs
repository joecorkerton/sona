defmodule SonaWeb.SessionControllerTest do
  use SonaWeb.ConnCase

  alias Sona.Accounts

  describe "POST /session" do
    test "creates company and user, sets cookie, redirects to /chats", %{conn: conn} do
      conn =
        post(conn, ~p"/session", %{
          company_name: "Test Hotel",
          username: "manager",
          display_name: "Manager"
        })

      assert redirected_to(conn) == "/chats"
      assert get_session(conn, "user_id")

      user_id = get_session(conn, "user_id")
      user = Sona.Repo.get!(Sona.Accounts.User, user_id)
      assert user.username == "manager"
    end

    test "sets invite_token on the company", %{conn: conn} do
      conn =
        post(conn, ~p"/session", %{company_name: "Test Hotel", username: "manager"})

      user_id = get_session(conn, "user_id")
      user = Sona.Repo.get!(Sona.Accounts.User, user_id) |> Sona.Repo.preload(:company)
      assert user.company.invite_token
    end
  end

  describe "POST /join/:token/session" do
    test "joins existing company, sets cookie, and redirects", %{conn: conn} do
      {:ok, {company, creator}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      Sona.Chats.ensure_default_room(company, creator)

      conn =
        post(conn, ~p"/join/demo-hotel/session", %{username: "bob"})

      assert redirected_to(conn) == "/chats"
      assert get_session(conn, "user_id")

      user_id = get_session(conn, "user_id")
      user = Sona.Repo.get!(Sona.Accounts.User, user_id)
      assert user.username == "bob"
      assert user.company_id == company.id
    end

    test "returns 302 (not 500) for unknown token", %{conn: conn} do
      conn = post(conn, ~p"/join/nonexistent/session", %{username: "bob"})

      assert redirected_to(conn) == "/"
      refute get_session(conn, "user_id")
    end

    test "re-joining with same username returns existing user", %{conn: conn} do
      {:ok, {company, creator}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      Sona.Chats.ensure_default_room(company, creator)

      conn1 =
        post(conn, ~p"/join/demo-hotel/session", %{username: "bob"})

      user_id_1 = get_session(conn1, "user_id")
      assert user_id_1, "expected user_id to be set on first join"

      conn2 =
        post(build_conn(), ~p"/join/demo-hotel/session", %{username: "bob"})

      user_id_2 = get_session(conn2, "user_id")
      assert user_id_2, "expected user_id to be set on second join"

      assert user_id_1 == user_id_2
    end

    test "returns error for empty username", %{conn: conn} do
      {:ok, {_company, _}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      conn = post(conn, ~p"/join/demo-hotel/session", %{username: ""})

      assert redirected_to(conn) == "/join/demo-hotel"
      refute get_session(conn, "user_id")
    end

    test "returns error for invalid username characters", %{conn: conn} do
      {:ok, {_company, _}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      conn = post(conn, ~p"/join/demo-hotel/session", %{username: "bad username!"})

      assert redirected_to(conn) == "/join/demo-hotel"
      refute get_session(conn, "user_id")
    end

    test "returns error when company has no General room", %{conn: conn} do
      {:ok, {_company, _}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      conn = post(conn, ~p"/join/demo-hotel/session", %{username: "bob"})

      assert redirected_to(conn) == "/"
      refute get_session(conn, "user_id")
    end
  end

  describe "DELETE /session" do
    test "clears user_id cookie and redirects to /", %{conn: conn} do
      {:ok, {_company, user}} =
        Accounts.create_company(%{name: "Test", username: "alice", invite_token: "tok"})

      conn =
        conn
        |> log_in_user(user)
        |> delete(~p"/session")

      assert redirected_to(conn) == "/"
      refute get_session(conn, "user_id")
    end
  end
end
