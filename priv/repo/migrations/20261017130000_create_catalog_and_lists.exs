defmodule Zipfelschmaus.Repo.Migrations.CreateCatalogAndLists do
  use Ecto.Migration

  def change do
    create table(:areas) do
      add :key, :string, null: false
      add :name, :string, null: false
      add :position, :integer, null: false

      timestamps()
    end

    create unique_index(:areas, [:key])

    create table(:articles) do
      add :name, :string, null: false
      add :folded_name, :string, null: false
      add :area_id, references(:areas, on_delete: :restrict), null: false
      add :picture, :string

      timestamps()
    end

    create unique_index(:articles, [:folded_name])
    create index(:articles, [:area_id])

    create table(:lists) do
      add :owner_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :shared, :boolean, null: false, default: false

      timestamps()
    end

    create index(:lists, [:owner_id])

    create table(:entries) do
      add :list_id, references(:lists, on_delete: :delete_all), null: false
      add :article_id, references(:articles, on_delete: :restrict), null: false
      add :detail, :string
      add :checked_off_at, :utc_datetime_usec
      add :check_changed_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create unique_index(:entries, [:list_id, :article_id])
    create index(:entries, [:article_id])
  end
end
