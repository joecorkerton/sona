defmodule SonaWeb.JoinLiveTest do
  use SonaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sona.Accounts

  describe "GET /join/:token" do
    test "renders the LiveView with company name for a valid token", %{conn: conn} do
      {:ok, {company, _}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      {:ok, view, html} = live(conn, ~p"/join/demo-hotel")

      assert has_element?(view, "#join-form")
      assert html =~ "Join #{company.name}"
      assert html =~ "Test Hotel"
    end

    test "has a form that POSTs to the session controller", %{conn: conn} do
      {:ok, {_company, _}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      {:ok, view, _html} = live(conn, ~p"/join/demo-hotel")

      form = element(view, "#join-form")
      rendered_form = render(form)

      assert rendered_form =~ ~p"/join/demo-hotel/session"
      assert rendered_form =~ "method=\"post\""
    end

    test "shows invalid token UX for unknown token", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/join/nonexistent")

      assert html =~ "Invalid invite link"
      assert html =~ "not valid"
    end

    test "includes Layouts.app with current_scope", %{conn: conn} do
      {:ok, {_company, _}} =
        Accounts.create_company(%{
          name: "Test Hotel",
          username: "alice",
          invite_token: "demo-hotel"
        })

      {:ok, view, _html} = live(conn, ~p"/join/demo-hotel")

      # The template uses Layouts.app which renders the layout header
      assert has_element?(view, "header")
    end
  end

  describe "form submission via SessionController" do
    test "POST to /join/:token/session sets cookie and redirects", %{conn: conn} do
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

      conn2 =
        post(build_conn(), ~p"/join/demo-hotel/session", %{username: "bob"})

      user_id_2 = get_session(conn2, "user_id")

      assert user_id_1 == user_id_2
    end

    test "adds user to General room", %{conn: conn} do
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

      user_id = get_session(conn, "user_id")
      user = Sona.Repo.get!(Sona.Accounts.User, user_id)

      rooms = Sona.Chats.list_rooms_for_user(user)
      general = Enum.find(rooms, &(&1.name == "General"))
      assert general
    end

    test "cross-company join overwrites user_id", %{conn: conn} do
      {:ok, {company1, user1}} =
        Accounts.create_company(%{
          name: "Hotel One",
          username: "alice",
          invite_token: "hotel-one"
        })

      {:ok, {company2, user2}} =
        Accounts.create_company(%{
          name: "Hotel Two",
          username: "bob",
          invite_token: "hotel-two"
        })

      Sona.Chats.ensure_default_room(company1, user1)
      Sona.Chats.ensure_default_room(company2, user2)

      conn =
        conn
        |> log_in_user(user1)
        |> post(~p"/join/hotel-two/session", %{username: "charlie"})

      assert redirected_to(conn) == "/chats"

      new_user_id = get_session(conn, "user_id")
      refute new_user_id == user1.id

      new_user = Sona.Repo.get!(Sona.Accounts.User, new_user_id)
      assert new_user.username == "charlie"
    end
  end
end
