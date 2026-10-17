defmodule Zipfelschmaus.Catalog.Article do
  @moduledoc """
  A thing the household buys, once per household: its name is unique regardless of case
  (`folded_name`). `picture` is optional; without one the article shows its area's.
  """
  use Zipfelschmaus.Schema

  import Ecto.Changeset

  alias Zipfelschmaus.Catalog.Area
  alias Zipfelschmaus.Names

  schema "articles" do
    field :name, :string
    field :folded_name, :string
    field :picture, :string

    belongs_to :area, Area

    timestamps()
  end

  def create_changeset(article, attrs) do
    article
    |> cast(attrs, [:name, :area_id])
    |> update_change(:name, &Names.normalize/1)
    |> validate_required([:name, :area_id])
    |> validate_length(:name, max: 80)
    |> put_folded_name()
    |> unique_constraint(:folded_name)
  end

  defp put_folded_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :folded_name, Names.fold(name))
    end
  end
end
