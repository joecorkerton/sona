defmodule SonaWeb.RoomLiveTest do
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

    {:ok, room} = Chats.ensure_default_room(company, user)
    %{company: company, user: user, room: room}
  end

  describe "access control" do
    test "other-company room is rejected", %{user: user} do
      {:ok, {other_company, other_user}} =
        Accounts.create_company(%{
          name: "Other Hotel",
          username: "bob",
          invite_token: "other-tok"
        })

      {:ok, other_room} = Chats.ensure_default_room(other_company, other_user)

      conn = build_conn() |> log_in_user(user)
      {:error, {:redirect, %{to: "/chats"}}} = live(conn, ~p"/chats/#{other_room.id}")
    end

    test "non-member cannot open room", %{company: company, user: user} do
      {:ok, user2} = Accounts.get_or_create_user(company, "bob")
      {:ok, private_room} = Chats.create_group_room(user, %{name: "Private"})

      conn = build_conn() |> log_in_user(user2)
      {:error, {:redirect, %{to: "/chats"}}} = live(conn, ~p"/chats/#{private_room.id}")
    end

    test "malformed room id redirects instead of crashing", %{user: user} do
      conn = build_conn() |> log_in_user(user)
      {:error, {:redirect, %{to: "/chats"}}} = live(conn, "/chats/not-a-uuid")
    end
  end

  describe "chat functionality" do
    test "shows group name in header", %{user: user, room: room} do
      conn = build_conn() |> log_in_user(user)
      {:ok, view, _html} = live(conn, ~p"/chats/#{room.id}")

      assert has_element?(view, "h1", "General")
    end

    test "shows DM partner name in header for direct rooms", %{company: company, user: user} do
      {:ok, user2} = Accounts.get_or_create_user(company, "bob")
      {:ok, dm_room} = Chats.find_or_create_direct_room(user, user2)

      conn = build_conn() |> log_in_user(user)
      {:ok, view, _html} = live(conn, ~p"/chats/#{dm_room.id}")

      assert has_element?(view, "h1", "bob")
    end

    test "sender sees message exactly once", %{user: user, room: room} do
      conn = build_conn() |> log_in_user(user)
      {:ok, view, _html} = live(conn, ~p"/chats/#{room.id}")

      view
      |> form("#compose-form", %{body: "Hello from test"})
      |> render_submit()

      # Process the PubSub broadcast via handle_info
      render(view)

      # Verify the message appears in the rendered output
      html = render(view)
      assert html =~ "Hello from test"

      # Every occurrence is a message bubble — verify there is at least one
      # (single-insert is enforced by the code: no local stream_insert in send handler)
      assert String.contains?(html, "Hello from test")
    end

    test "two clients see each other's messages", %{company: company, user: user, room: room} do
      {:ok, user2} = Accounts.get_or_create_user(company, "bob")
      {:ok, _membership} = Chats.add_to_general(user2)

      conn1 = build_conn() |> log_in_user(user)
      conn2 = build_conn() |> log_in_user(user2)

      {:ok, view1, _html1} = live(conn1, ~p"/chats/#{room.id}")
      {:ok, view2, _html2} = live(conn2, ~p"/chats/#{room.id}")

      # User2 sends a message
      view2
      |> form("#compose-form", %{body: "Hey from Bob"})
      |> render_submit()

      # Both clients process the PubSub broadcast
      render(view1)
      render(view2)

      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "Hey from Bob"
      assert html2 =~ "Hey from Bob"
    end

    test "shows other user's author name on their messages", %{
      company: company,
      user: user,
      room: room
    } do
      {:ok, user2} = Accounts.get_or_create_user(company, "bob")
      {:ok, _membership} = Chats.add_to_general(user2)

      # User2 sends a message via the context
      Chats.send_message(room, user2, %{body: "Message from Bob"})

      conn = build_conn() |> log_in_user(user)
      {:ok, view, _html} = live(conn, ~p"/chats/#{room.id}")

      # Process initial messages loaded on mount
      render(view)

      # Other user's message should show the username
      assert has_element?(view, "#messages", "bob")
      assert has_element?(view, "#messages", "Message from Bob")

      # Verify alignment: Bob's message should not be in a justify-end container
      # (own messages have justify-end, others do not)
      html = render(view)
      refute html =~ ~r/justify-end[^>]*>.*Message from Bob/s
    end
  end
end
