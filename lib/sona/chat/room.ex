defmodule Sona.Chat.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "rooms" do
    field :type, Ecto.Enum, values: [:direct, :group]
    field :name, :string
    field :direct_token, :string
    belongs_to :company, Sona.Accounts.Company

    has_many :memberships, Sona.Chat.Membership

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:company_id, :type, :name, :direct_token])
    |> validate_required([:type])
    |> validate_room_name()
    |> unique_constraint(:direct_token)
  end

  defp validate_room_name(changeset) do
    case get_field(changeset, :type) do
      :group -> validate_required(changeset, [:name])
      _ -> changeset
    end
  end
end
