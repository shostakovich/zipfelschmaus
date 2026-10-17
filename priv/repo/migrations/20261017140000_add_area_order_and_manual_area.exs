defmodule Zipfelschmaus.Repo.Migrations.AddAreaOrderAndManualArea do
  use Ecto.Migration

  def up do
    alter table(:lists) do
      add :area_order, :text, null: false, default: "[]"
    end

    alter table(:articles) do
      add :area_set_by_hand, :boolean, null: false, default: false
    end

    flush()

    execute("""
    UPDATE lists SET area_order =
      (SELECT json_group_array(id ORDER BY position, id) FROM areas)
    """)
  end

  def down do
    alter table(:articles) do
      remove :area_set_by_hand
    end

    alter table(:lists) do
      remove :area_order
    end
  end
end
