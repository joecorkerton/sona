defmodule SonaWeb.InboxLiveTest do
  use SonaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sona.Accounts
  alias Sona.Chats

  setup do
    {:ok, {company, user}} =
      Accounts.create_company(%{
        name: "Test Hotel",
        username: "alice",
        invite_token: "demo-hotel"
      })

    {:ok, _room} = Chats.ensure_default_room(company, user)

    %{company: company, user: user}
  end

  describe "GET /chats (InboxLive)" do
    test "renders the inbox for a logged-in user", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#company-header h1", "Test Hotel")
    end

    test "includes Layouts.app with current_scope", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "header")
      assert has_element?(view, "main")
    end

    test "redirects unauthenticated visitor to /", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, "/chats")
    end
  end

  describe "company header" do
    test "shows the company name", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#company-header")
      assert has_element?(view, "#company-header h1", "Test Hotel")
    end
  end

  describe "invite link" do
    test "shows the shareable invite URL with the company token", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#invite-link")
      assert has_element?(view, "#invite-url", "/join/demo-hotel")
    end
  end

  describe "entry points" do
    test "shows the New group button", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#new-group-button", "New group")
    end

    test "shows the New message button", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#new-message-button", "New message")
    end
  end

  describe "rooms list" do
    test "lists the user's rooms", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#rooms", "General")
    end

    test "rooms link to /chats/:room_id", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      room = Chats.list_rooms_for_user(user) |> hd()
      assert has_element?(view, "#rooms a[href='/chats/#{room.id}']", "General")
    end

    test "does not show rooms from other companies", %{conn: conn, user: user} do
      {:ok, {other_company, other_user}} =
        Accounts.create_company(%{
          name: "Other Hotel",
          username: "bob",
          invite_token: "other-tok"
        })

      {:ok, _other_room} = Chats.ensure_default_room(other_company, other_user)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      # Only the current user's room(s) are listed — the other company's
      # General room (named "General") must not show up as that user's room
      other_room = Chats.list_rooms_for_user(other_user) |> hd()
      refute has_element?(view, "#rooms-#{other_room.id}")

      my_rooms = Chats.list_rooms_for_user(user)
      assert length(my_rooms) == 1
      assert hd(my_rooms).company_id == user.company_id
    end

    test "shows the other user's name in a direct room", %{
      company: company,
      conn: conn,
      user: alice
    } do
      {:ok, bob} = Accounts.get_or_create_user(company, "bob")
      {:ok, _dm} = Chats.find_or_create_direct_room(alice, bob)

      conn = log_in_user(conn, alice)
      {:ok, view, _html} = live(conn, "/chats")

      # The DM room card shows bob's name
      assert has_element?(view, "#rooms", "bob")
    end

    test "shows empty state when the user has no rooms", %{company: company, conn: conn} do
      {:ok, charlie} = Accounts.get_or_create_user(company, "charlie")

      conn = log_in_user(conn, charlie)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#rooms-empty")
    end
  end
end
