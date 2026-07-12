defmodule Sona.Guide.GuideConversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "guide_conversations" do
    belongs_to :company, Sona.Accounts.Company
    belongs_to :user, Sona.Accounts.User

    timestamps()
  end

  def changeset(guide_conversation, attrs) do
    guide_conversation
    |> cast(attrs, [])
    |> validate_required([:company_id, :user_id])
    |> unique_constraint(:user_id)
  end
end
