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

    if is_nil(username) or username == "" do
      conn
      |> put_flash(:error, "Username is required")
      |> redirect(to: "/join/#{token}")
    else
      company = Sona.Accounts.get_company_by_invite_token(token)

      cond do
        is_nil(company) ->
          conn
          |> put_flash(:error, "Invalid invite link")
          |> redirect(to: "/")

        true ->
          case Sona.Accounts.get_or_create_user(company, username) do
            {:ok, user} ->
              case Sona.Chats.add_to_general(user) do
                {:ok, _membership} ->
                  conn
                  |> put_session("user_id", user.id)
                  |> redirect(to: "/chats")

                {:error, :no_general_room} ->
                  conn
                  |> put_flash(:error, "Company has no workspace configured")
                  |> redirect(to: "/")
              end

            {:error, _changeset} ->
              conn
              |> put_flash(:error, "Invalid username")
              |> redirect(to: "/join/#{token}")
          end
      end
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session("user_id")
    |> redirect(to: "/")
  end
end
