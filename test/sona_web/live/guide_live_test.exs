defmodule SonaWeb.GuideLiveTest do
  use SonaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sona.Accounts
  alias Sona.Guide

  setup do
    {:ok, {company, user}} =
      Accounts.create_company(%{
        name: "Test Hotel",
        username: "alice",
        invite_token: "guide-tok"
      })

    %{company: company, user: user}
  end

  describe "GET /guide (GuideLive)" do
    test "renders the guide for a logged-in user", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "#guide-header-name", "Sona Guide")
    end

    test "wraps content in Layouts.app with current_scope", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "header#app-header")
      assert has_element?(view, "main")
      assert has_element?(view, "#sona-wordmark", "Sona.")
      assert has_element?(view, "#user-company-label", "alice @ Test Hotel")
    end

    test "redirects unauthenticated visitor to /", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/guide")
    end
  end

  describe "auto-ensures conversation" do
    test "creates a guide conversation row on first mount", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, _view, _html} = live(conn, ~p"/guide")

      # Conversation row now exists
      conversation = Guide.ensure_conversation(user)
      assert conversation.user_id == user.id
      assert conversation.company_id == user.company_id
    end

    test "shows the empty state when the conversation has no messages", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "#guide-messages-empty")
      refute has_element?(view, "[data-role='user']")
      refute has_element?(view, "[data-role='assistant']")
    end
  end

  describe "header" do
    test "shows 'Sona Guide' with a guide (sparkles) icon", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "#guide-header-name", "Sona Guide")
      # sparkles heroicon present in the guide header (a <span class="hero-sparkles ...">)
      assert has_element?(view, ".hero-sparkles")
    end
  end

  describe "composer" do
    test "has the guide-compose-form id and phx-submit=send", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "form#guide-compose-form")
      assert has_element?(view, "form#guide-compose-form[phx-submit='send']")
    end

    test "is enabled on initial mount", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      refute has_element?(view, "#guide-compose-form input[disabled]")
      refute has_element?(view, "#guide-compose-form button[disabled]")
    end
  end

  describe "sending a message" do
    test "sends a message and shows the user + assistant bubbles once each", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      view
      |> form("#guide-compose-form", %{body: "Hello from test"})
      |> render_submit()

      # Process the PubSub broadcasts via handle_info
      render(view)

      # User message bubble
      assert has_element?(view, "[data-role='user']", "Hello from test")

      # Assistant (guide) reply — the stub returns this fixed string
      assert has_element?(
               view,
               "[data-role='assistant']",
               "This is a stub reply from the AI Guide."
             )

      # Single-insert rule: the user body and the assistant reply each
      # appear in exactly one streamed message bubble
      html = render(view)
      assert count_message_bubbles(html, "Hello from test") == 1
      assert count_message_bubbles(html, "This is a stub reply from the AI Guide.") == 1
    end

    test "re-enables the composer after the assistant reply lands", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      view
      |> form("#guide-compose-form", %{body: "Hi"})
      |> render_submit()

      # Drain both broadcasts (user + assistant)
      render(view)

      # After the assistant broadcast, thinking=false → input enabled
      refute has_element?(view, "#guide-compose-form input[disabled]")
      refute has_element?(view, "#guide-compose-form button[disabled]")
    end
  end

  describe "seeded proactive message" do
    test "shows the proactive guide bubble on mount", %{conn: conn, user: user} do
      Guide.seed_proactive_message(user, "Welcome to the AI Guide!")

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "[data-role='assistant']", "Welcome to the AI Guide!")
    end

    test "preserves the proactive message when the user follows up", %{
      conn: conn,
      user: user
    } do
      Guide.seed_proactive_message(user, "Welcome to the AI Guide!")

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      view
      |> form("#guide-compose-form", %{body: "Thanks!"})
      |> render_submit()

      render(view)

      # All three messages: proactive + user + assistant reply
      assert has_element?(view, "[data-role='assistant']", "Welcome to the AI Guide!")
      assert has_element?(view, "[data-role='user']", "Thanks!")

      assert has_element?(
               view,
               "[data-role='assistant']",
               "This is a stub reply from the AI Guide."
             )
    end
  end

  describe "error path" do
    test "shows a flash error and retains the user's text in the input", %{
      conn: conn,
      user: user
    } do
      Application.put_env(:sona, :guide_llm_stub_should_error, true)

      try do
        conn = log_in_user(conn, user)
        {:ok, view, _html} = live(conn, ~p"/guide")

        view
        |> form("#guide-compose-form", %{body: "Will this fail?"})
        |> render_submit()

        render(view)

        # Flash error is shown
        assert has_element?(view, ".alert-error", "Couldn't reach the guide")

        # User's text is retained in the input for retry
        assert has_element?(
                 view,
                 "#guide-compose-form input[name='body'][value='Will this fail?']"
               )

        # Composer re-enabled
        refute has_element?(view, "#guide-compose-form input[disabled]")
        refute has_element?(view, "#guide-compose-form button[disabled]")
      after
        Application.delete_env(:sona, :guide_llm_stub_should_error)
      end
    end

    test "persists the user message even on LLM error", %{conn: conn, user: user} do
      Application.put_env(:sona, :guide_llm_stub_should_error, true)

      try do
        conn = log_in_user(conn, user)
        {:ok, view, _html} = live(conn, ~p"/guide")

        view
        |> form("#guide-compose-form", %{body: "Persisted user msg"})
        |> render_submit()

        render(view)

        # User message is in the DOM even though no assistant reply will come
        assert has_element?(view, "[data-role='user']", "Persisted user msg")
        # No assistant reply was broadcast
        refute has_element?(
                 view,
                 "[data-role='assistant']",
                 "This is a stub reply from the AI Guide."
               )
      after
        Application.delete_env(:sona, :guide_llm_stub_should_error)
      end
    end
  end

  describe "history restoration" do
    test "re-opening /guide restores the full guide history", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      # Send a message (creates user + assistant)
      view
      |> form("#guide-compose-form", %{body: "First message"})
      |> render_submit()

      render(view)

      # Stop the LiveView (simulate closing the tab) and re-open
      {:ok, view, _html} = live(conn, ~p"/guide")

      assert has_element?(view, "[data-role='user']", "First message")

      assert has_element?(
               view,
               "[data-role='assistant']",
               "This is a stub reply from the AI Guide."
             )
    end
  end

  describe "visual distinction from coworker chats" do
    test "assistant bubbles are left-aligned, user bubbles are right-aligned", %{
      conn: conn,
      user: user
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/guide")

      view
      |> form("#guide-compose-form", %{body: "Hello"})
      |> render_submit()

      render(view)

      # User bubble row has justify-end
      assert has_element?(view, "[data-role='user'].justify-end")
      # Assistant bubble row does NOT have justify-end
      refute has_element?(view, "[data-role='assistant'].justify-end")

      # Assistant uses the guide accent (sona-lime), user uses primary
      assert has_element?(view, "[data-role='assistant'] .bg-sona-lime")
      assert has_element?(view, "[data-role='user'] .bg-primary")
    end
  end

  # Counts how many `data-role` message bubbles contain the given text in
  # the rendered HTML — used to assert single-insert behaviour without
  # resorting to raw HTML regex over the whole document.
  defp count_message_bubbles(html, text) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("[data-role]")
    |> Enum.count(fn bubble -> String.contains?(LazyHTML.text(bubble), text) end)
  end
end
