defmodule SonaWeb.SessionController do
  use SonaWeb, :controller

  def create(conn, params) do
    attrs = %{
      name: params["company_name"],
      username: params["username"],
      display_name: params["display_name"]
    }

    {:ok, {company, user}} = Sona.Accounts.create_company(attrs)
    Sona.Chats.ensure_default_room(company, user)

    conn
    |> put_session("user_id", user.id)
    |> redirect(to: "/chats")
  end

  def join(conn, params) do
    token = params["token"]
    username = params["username"]

    company = Sona.Accounts.get_company_by_invite_token(token)

    if is_nil(company) do
      conn
      |> put_flash(:error, "Invalid invite link")
      |> redirect(to: "/")
    else
      {:ok, user} = Sona.Accounts.get_or_create_user(company, username)
      Sona.Chats.add_to_general(user)

      conn
      |> put_session("user_id", user.id)
      |> redirect(to: "/chats")
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session("user_id")
    |> redirect(to: "/")
  end
end
