defmodule Sona.Chat.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memberships" do
    belongs_to :room, Sona.Chat.Room
    belongs_to :user, Sona.Accounts.User

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [])
    |> unique_constraint(:room_id, name: :memberships_room_id_user_id_index)
    |> unique_constraint(:user_id, name: :memberships_room_id_user_id_index)
  end
end
