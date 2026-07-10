defmodule Sona.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :body, :string
    belongs_to :room, Sona.Chat.Room
    belongs_to :user, Sona.Accounts.User
    belongs_to :parent, __MODULE__, foreign_key: :parent_id, type: :binary_id

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
