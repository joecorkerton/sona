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
      missing_username(conn, token)
    else
      case fetch_user(token, username) do
        {:ok, user} -> sign_in_user(conn, user)
        :invalid_invite -> invalid_invite(conn)
        {:error, _changeset} -> invalid_username(conn, token)
      end
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session("user_id")
    |> redirect(to: "/")
  end

  defp fetch_user(token, username) do
    with %{} = company <- Sona.Accounts.get_company_by_invite_token(token),
         {:ok, user} <- Sona.Accounts.get_or_create_user(company, username) do
      {:ok, user}
    else
      nil -> :invalid_invite
      error -> error
    end
  end

  defp sign_in_user(conn, user) do
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
  end

  defp missing_username(conn, token) do
    conn
    |> put_flash(:error, "Username is required")
    |> redirect(to: "/join/#{token}")
  end

  defp invalid_invite(conn) do
    conn
    |> put_flash(:error, "Invalid invite link")
    |> redirect(to: "/")
  end

  defp invalid_username(conn, token) do
    conn
    |> put_flash(:error, "Invalid username")
    |> redirect(to: "/join/#{token}")
  end
end
