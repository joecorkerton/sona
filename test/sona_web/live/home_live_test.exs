defmodule SonaWeb.HomeLiveTest do
  use SonaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Sona.Accounts
  alias Sona.Chat.Room
  alias Sona.Repo

  describe "GET / (HomeLive) — guest" do
    test "renders the create company form", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Create your workplace"
      assert has_element?(view, "#new-company-form")
      assert has_element?(view, "input[name=\"company_name\"]")
      assert has_element?(view, "input[name=\"username\"]")
    end

    test "form submits to SessionController.create, creates company + user + General room, sets cookie, redirects to /chats",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      form = form(view, "#new-company-form", %{company_name: "Test Hotel", username: "alice"})

      result_conn = submit_form(form, conn)

      assert result_conn.status == 302
      assert Phoenix.ConnTest.redirected_to(result_conn, 302) == "/chats"

      user_id = Plug.Conn.get_session(result_conn, "user_id")
      assert user_id != nil

      user = Repo.get!(Sona.Accounts.User, user_id)
      assert user.username == "alice"

      company = Repo.preload(user, :company).company
      assert company.name == "Test Hotel"
      assert company.invite_token != nil

      # Verify General room exists
      [room] = Repo.all(Room)
      assert room.name == "General"
      assert room.company_id == company.id
    end
  end

  describe "GET / (HomeLive) — authenticated" do
    test "redirects to /chats when already logged in", %{conn: conn} do
      {:ok, {_company, user}} =
        Accounts.create_company(%{name: "Existing Co", username: "existing", invite_token: "tok"})

      user = Repo.preload(user, :company)

      conn =
        conn
        |> log_in_user(user)

      assert {:error, {:live_redirect, %{to: "/chats"}}} = live(conn, "/")
    end
  end
end
