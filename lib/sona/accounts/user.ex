defmodule Sona.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :display_name, :string
    belongs_to :company, Sona.Accounts.Company

    has_many :messages, Sona.Chat.Message
    has_many :memberships, Sona.Chat.Membership

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :display_name])
    |> validate_required([:username])
    |> normalize_username()
    |> validate_length(:username, max: 50)
    |> validate_format(:username, ~r/^[a-z0-9_.-]+$/,
      message: "can only contain lowercase letters, numbers, dots, underscores, and hyphens"
    )
    |> put_display_name()
    |> unique_constraint(:username, name: :users_company_id_username_index)
  end

  defp normalize_username(changeset) do
    case get_change(changeset, :username) do
      nil -> changeset
      username -> put_change(changeset, :username, String.downcase(username))
    end
  end

  defp put_display_name(changeset) do
    case get_change(changeset, :display_name) do
      nil ->
        case get_change(changeset, :username) do
          nil -> changeset
          username -> put_change(changeset, :display_name, username)
        end

      _ ->
        changeset
    end
  end
end
