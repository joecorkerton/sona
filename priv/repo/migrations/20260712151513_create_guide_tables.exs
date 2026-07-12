defmodule Sona.Repo.Migrations.CreateGuideTables do
  use Ecto.Migration

  def change do
    create table(:guide_conversations, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :company_id, references(:companies, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:guide_conversations, [:user_id])
    create index(:guide_conversations, [:company_id])

    create table(:guide_messages, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :conversation_id, references(:guide_conversations, type: :uuid, on_delete: :delete_all),
        null: false

      add :role, :string, null: false
      add :body, :text, null: false
      timestamps()
    end

    create index(:guide_messages, [:conversation_id, :inserted_at])
  end
end
