defmodule Sona.Repo.Migrations.AddUniqueIndexOnRoomsCompanyTypeName do
  use Ecto.Migration

  def change do
    create unique_index(:rooms, [:company_id, :type, :name])
  end
end
