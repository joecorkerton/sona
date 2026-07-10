defmodule Sona.Accounts do
  @moduledoc """
  Context for companies and users.

  Handles company creation, invite tokens, and the lifecycle of users
  (lookup / upsert) within a company.
  """

  alias Sona.Accounts.{Company, User}
  alias Sona.Repo

  def create_company(attrs \\ %{}) do
    invite_token = Map.get(attrs, :invite_token) || generate_invite_token()

    Repo.transaction(fn ->
      with {:ok, company} <-
             %Company{}
             |> Company.changeset(attrs)
             |> Ecto.Changeset.put_change(:invite_token, invite_token)
             |> Repo.insert(),
           {:ok, user} <-
             %User{company_id: company.id}
             |> User.changeset(attrs)
             |> Repo.insert() do
        {company, user}
      else
        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def get_company_by_invite_token(token) do
    Repo.get_by(Company, invite_token: token)
  end

  def get_or_create_user(%Company{} = company, username) do
    normalized = String.downcase(username)
    do_get_or_create(company, normalized)
  end

  defp do_get_or_create(company, normalized) do
    %User{company_id: company.id}
    |> User.changeset(%{username: normalized})
    |> Repo.insert()
    |> case do
      {:ok, user} ->
        {:ok, user}

      {:error, changeset} ->
        if constraint_error?(changeset, :username) do
          {:ok, Repo.get_by!(User, company_id: company.id, username: normalized)}
        else
          {:error, changeset}
        end
    end
  rescue
    Ecto.ConstraintError ->
      {:ok, Repo.get_by!(User, company_id: company.id, username: normalized)}
  end

  defp generate_invite_token do
    Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
  end

  defp constraint_error?(changeset, field) do
    case changeset.errors[field] do
      {_msg, opts} when is_list(opts) -> opts[:constraint] == :unique
      _ -> false
    end
  end
end
