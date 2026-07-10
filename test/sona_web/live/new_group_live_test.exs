defmodule SonaWeb.NewGroupLiveTest do
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

  describe "GET /chats/new/group" do
    test "renders the new group form", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/chats/new/group")

      assert has_element?(view, "#new-group-form")
      assert has_element?(view, "input#new-group-form_name")
    end

    test "redirects unauthenticated visitor to /", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/chats/new/group")
    end
  end

  describe "create group" do
    test "creates a group room and opens it", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/chats/new/group")

      view
      |> form("#new-group-form", %{"group" => %{"name" => "Engineering"}})
      |> render_submit()

      {path, _flash} = assert_redirect(view)
      assert path =~ ~r"^/chats/[0-9a-f-]+$"
    end

    test "created group appears in the inbox", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/chats/new/group")

      view
      |> form("#new-group-form", %{"group" => %{"name" => "Engineering"}})
      |> render_submit()

      assert_redirect(view)

      {:ok, inbox_view, _html} = live(conn, ~p"/chats")
      assert has_element?(inbox_view, "#rooms", "Engineering")
    end

    test "shows validation errors for missing name", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/chats/new/group")

      view
      |> form("#new-group-form", %{"group" => %{"name" => ""}})
      |> render_submit()

      assert has_element?(view, "#new-group-form")
      assert has_element?(view, "input.input-error")
      assert has_element?(view, "#new-group-form", "can't be blank")
    end
  end
end
