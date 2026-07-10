defmodule Sona.Accounts.Company do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "companies" do
    field :name, :string
    field :invite_token, :string

    has_many :users, Sona.Accounts.User
    has_many :rooms, Sona.Chat.Room

    timestamps()
  end

  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
