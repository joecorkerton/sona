defmodule SonaWeb.InboxLiveTest do
  use SonaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sona.Accounts
  alias Sona.Chats
  alias Sona.Guide
  alias Sona.Guide.GuideConversation
  alias Sona.Guide.GuideMessage

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

      assert has_element?(view, "header#app-header")
      assert has_element?(view, "main")
      assert has_element?(view, "#sona-wordmark", "Sona.")
      assert has_element?(view, "#user-company-label", "alice @ Test Hotel")
      assert has_element?(view, "#sign-out-form")
      assert has_element?(view, "#sign-out-form input[name=\"_method\"][value=\"delete\"]")
      assert has_element?(view, "#sign-out-button", "Sign out")
      assert has_element?(view, "#flash-group")
      refute has_element?(view, "[data-phx-theme]")
    end

    test "sign-out form clears the session and redirects to /", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      form = form(view, "#sign-out-form", %{})
      result_conn = submit_form(form, conn)

      assert result_conn.status == 302
      assert Phoenix.ConnTest.redirected_to(result_conn, 302) == "/"
      refute Plug.Conn.get_session(result_conn, "user_id")
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

    test "copy button is wired to a clipboard hook (not dead UI)", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#copy-invite-button[phx-hook='SonaWeb.InboxLive.CopyInvite']")
      assert has_element?(view, "#copy-invite-button[phx-update='ignore']")
      assert has_element?(view, "#copy-invite-button[data-copy-target='#invite-url']")
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

  describe "guide section" do
    test "renders a #guide-section element with its own heading", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#guide-section")
      assert has_element?(view, "#guide-section-heading", "Guide")
    end

    test "the guide section is structurally separate from the chats list", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      # Both exist, but #guide-section is not nested inside #rooms
      assert has_element?(view, "#rooms")
      assert has_element?(view, "#guide-section")

      # A descendant-combinator selector only matches when the inner element
      # is actually nested, so a negative has_element? is sufficient to
      # assert #guide-section is a sibling of #rooms (and any streamed room
      # row with id "rooms-..."), not a descendant.
      refute has_element?(view, "#guide-section #rooms")
      refute has_element?(view, "#guide-section [id^='rooms-']")

      # The chats list does not contain the guide heading "Sona Guide" — that
      # would only happen if the guide section were interleaved with room rows.
      refute has_element?(view, "#rooms", "Sona Guide")
    end

    test "the guide entry uses a sparkles icon, not a letter initial", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      # The link wraps a sparkles icon (an SVG sprite class)
      assert has_element?(view, "#guide-link .hero-sparkles")
    end

    test "the guide entry is a link to /guide (navigate, not patch)", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#guide-link[href='/guide']")
    end

    test "shows the latest guide message as a teaser", %{conn: conn, user: user} do
      body = "Here's how tomorrow looks — expect a busy breakfast rush."
      Guide.seed_proactive_message(user, body)

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#guide-teaser", body)
    end

    test "reflects the most recent message when there are several", %{conn: conn, user: user} do
      # Insert two messages with explicit, distinct inserted_at values so the
      # ordering is deterministic (latest_guide_summary/1 orders by inserted_at
      # desc, id desc — and the id tiebreaker is non-deterministic for random
      # binary UUIDs autogenerated by Ecto).
      conversation = Guide.ensure_conversation(user)

      insert_guide_message_with_at(
        conversation,
        :assistant,
        "First (older) guide note",
        ~N[2026-07-10 08:00:00]
      )

      insert_guide_message_with_at(
        conversation,
        :assistant,
        "Latest (most recent) guide note",
        ~N[2026-07-11 08:00:00]
      )

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#guide-teaser", "Latest (most recent) guide note")
      refute has_element?(view, "#guide-teaser", "First (older) guide note")
    end

    test "shows a 'Set up your guide' CTA when the guide has no messages", %{
      conn: conn,
      user: user
    } do
      # No messages seeded; latest_guide_summary/1 still returns a map but
      # with teaser: nil and the conversation row auto-ensured.
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, "/chats")

      assert has_element?(view, "#guide-empty-cta", "Set up your guide")
      refute has_element?(view, "#guide-teaser")
    end

    test "visiting /chats auto-ensures the guide conversation", %{conn: conn, user: user} do
      import Ecto.Query

      # Before loading /chats, no guide conversation exists for this user.
      refute Sona.Repo.exists?(from c in GuideConversation, where: c.user_id == ^user.id)

      conn = log_in_user(conn, user)
      {:ok, _view, _html} = live(conn, "/chats")

      # After loading, the conversation row exists (auto-ensured by
      # Sona.Guide.latest_guide_summary/1 in the InboxLive mount).
      assert Sona.Repo.exists?(from c in GuideConversation, where: c.user_id == ^user.id)
      # And there are still no messages
      assert Guide.list_messages(user) == []
    end
  end

  defp insert_guide_message_with_at(conversation, role, body, naive_datetime) do
    %GuideMessage{conversation_id: conversation.id}
    |> GuideMessage.changeset(%{body: body})
    |> Ecto.Changeset.put_change(:role, role)
    |> Ecto.Changeset.put_change(:inserted_at, naive_datetime)
    |> Ecto.Changeset.put_change(:updated_at, naive_datetime)
    |> Sona.Repo.insert!()
  end
end
