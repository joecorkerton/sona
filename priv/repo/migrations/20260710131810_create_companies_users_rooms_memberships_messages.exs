defmodule Sona.Repo.Migrations.CreateCompaniesUsersRoomsMembershipsMessages do
  use Ecto.Migration

  def change do
    create table(:companies, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :invite_token, :string, null: false
      timestamps()
    end

    create unique_index(:companies, :invite_token)

    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :company_id, references(:companies, type: :uuid, on_delete: :delete_all), null: false
      add :username, :string, null: false
      add :display_name, :string
      timestamps()
    end

    create unique_index(:users, [:company_id, :username])

    create table(:rooms, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :company_id, references(:companies, type: :uuid, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :name, :string
      add :direct_token, :string
      timestamps()
    end

    create unique_index(:rooms, [:direct_token])

    create table(:memberships, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :room_id, references(:rooms, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:memberships, [:room_id, :user_id])
    create index(:memberships, [:user_id])

    create table(:messages, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :room_id, references(:rooms, type: :uuid, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :parent_id, references(:messages, type: :uuid, on_delete: :nilify_all)
      timestamps()
    end

    create index(:messages, [:room_id, :inserted_at])
  end
end
