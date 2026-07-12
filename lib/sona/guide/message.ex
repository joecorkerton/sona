defmodule Sona.Guide.GuideMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "guide_messages" do
    belongs_to :conversation, Sona.Guide.GuideConversation, foreign_key: :conversation_id
    field :role, Ecto.Enum, values: [:user, :assistant]
    field :body, :string

    timestamps()
  end

  def changeset(guide_message, attrs) do
    guide_message
    |> cast(attrs, [:body])
    |> validate_required([:body])
  end
end
