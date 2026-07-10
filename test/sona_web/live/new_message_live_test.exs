defmodule SonaWeb.NewMessageLiveTest do
  use SonaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sona.Accounts
  alias Sona.Chats

  setup do
    {:ok, {company, user}} =
      Accounts.create_company(%{
        name: "Test Hotel",
        username: "alice",
        invite_token: "tok"
      })

    {:ok, _room} = Chats.ensure_default_room(company, user)

    %{company: company, user: user}
  end

  describe "GET /chats/new/message" do
    test "renders the DM picker", %{conn: conn, company: company, user: user} do
      {:ok, _bob} = Accounts.get_or_create_user(company, "bob")
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/chats/new/message")

      assert has_element?(view, "#new-message-form")
      assert has_element?(view, "select#new-message-form_user_id")
    end

    test "redirects unauthenticated visitor to /", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/chats/new/message")
    end
  end

  describe "DM picker" do
    test "lists company members excluding the current user", %{
      conn: conn,
      company: company,
      user: alice
    } do
      {:ok, _bob} = Accounts.get_or_create_user(company, "bob")
      conn = log_in_user(conn, alice)
      {:ok, view, _html} = live(conn, ~p"/chats/new/message")

      assert has_element?(view, "#new-message-form_user_id option", "bob")
      refute has_element?(view, "#new-message-form_user_id option", "alice")
    end

    test "does not list members from other companies", %{
      conn: conn,
      company: company,
      user: alice
    } do
      {:ok, _bob} = Accounts.get_or_create_user(company, "bob")

      {:ok, {other_company, _other_user}} =
        Accounts.create_company(%{
          name: "Other Hotel",
          username: "eve",
          invite_token: "other-tok"
        })

      {:ok, _charlie} = Accounts.get_or_create_user(other_company, "charlie")

      conn = log_in_user(conn, alice)
      {:ok, view, _html} = live(conn, ~p"/chats/new/message")

      assert has_element?(view, "#new-message-form_user_id option", "bob")
      refute has_element?(view, "#new-message-form_user_id option", "charlie")
    end
  end

  describe "start DM" do
    test "creates a direct room and opens it", %{
      conn: conn,
      company: company,
      user: alice
    } do
      {:ok, bob} = Accounts.get_or_create_user(company, "bob")
      conn = log_in_user(conn, alice)
      {:ok, view, _html} = live(conn, ~p"/chats/new/message")

      view
      |> form("#new-message-form", %{"message" => %{"user_id" => bob.id}})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"^/chats/[0-9a-f-]+$"
    end

    test "created DM appears in the inbox", %{
      conn: conn,
      company: company,
      user: alice
    } do
      {:ok, bob} = Accounts.get_or_create_user(company, "bob")
      conn = log_in_user(conn, alice)
      {:ok, view, _html} = live(conn, ~p"/chats/new/message")

      view
      |> form("#new-message-form", %{"message" => %{"user_id" => bob.id}})
      |> render_submit()

      assert_redirect(view)

      {:ok, inbox_view, _html} = live(conn, ~p"/chats")
      assert has_element?(inbox_view, "#rooms", "bob")
    end

    test "A↔B and B↔A resolve to the same room", %{
      company: company,
      user: alice
    } do
      {:ok, bob} = Accounts.get_or_create_user(company, "bob")

      conn_a = log_in_user(build_conn(), alice)
      {:ok, view_a, _html} = live(conn_a, ~p"/chats/new/message")

      view_a
      |> form("#new-message-form", %{"message" => %{"user_id" => bob.id}})
      |> render_submit()

      {path_a, _flash} = assert_redirect(view_a)

      conn_b = log_in_user(build_conn(), bob)
      {:ok, view_b, _html} = live(conn_b, ~p"/chats/new/message")

      view_b
      |> form("#new-message-form", %{"message" => %{"user_id" => alice.id}})
      |> render_submit()

      {path_b, _flash} = assert_redirect(view_b)

      assert path_a == path_b
    end

    test "messages flow bidirectionally in the new DM room", %{
      company: company,
      user: alice
    } do
      {:ok, bob} = Accounts.get_or_create_user(company, "bob")

      conn_a = log_in_user(build_conn(), alice)
      {:ok, view_a, _html} = live(conn_a, ~p"/chats/new/message")

      view_a
      |> form("#new-message-form", %{"message" => %{"user_id" => bob.id}})
      |> render_submit()

      {path, _flash} = assert_redirect(view_a)
      {:ok, view_a, _html} = live(conn_a, path)

      conn_b = log_in_user(build_conn(), bob)
      {:ok, view_b, _html} = live(conn_b, path)

      view_a
      |> form("#compose-form", %{body: "Hey Bob"})
      |> render_submit()

      render(view_b)

      assert has_element?(view_b, "#messages", "Hey Bob")
    end
  end
end
