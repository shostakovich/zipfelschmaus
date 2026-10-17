defmodule Zipfelschmaus.Catalog.Article do
  @moduledoc """
  A thing the household buys, once per household: its name is unique regardless of case
  (`folded_name`). `picture` is optional; without one the article shows its area's.
  `area_set_by_hand` marks an area someone chose, which a guess must not overwrite.
  """
  use Zipfelschmaus.Schema

  import Ecto.Changeset

  alias Zipfelschmaus.Catalog.Area
  alias Zipfelschmaus.Names

  schema "articles" do
    field :name, :string
    field :folded_name, :string
    field :picture, :string
    field :area_set_by_hand, :boolean, default: false

    belongs_to :area, Area

    timestamps()
  end

  def create_changeset(article, attrs) do
    article
    |> cast(attrs, [:name, :area_id])
    |> update_change(:name, &Names.normalize/1)
    |> validate_required([:name, :area_id])
    |> validate_name()
    |> put_folded_name()
    |> unique_constraint(:folded_name)
  end

  def validate_name(changeset), do: validate_length(changeset, :name, max: 80)

  # Forced: a guess moves the article behind the back of a struct loaded before it.
  def area_by_hand_changeset(article, %Area{id: area_id}),
    do: article |> change(area_set_by_hand: true) |> force_change(:area_id, area_id)

  defp put_folded_name(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name -> put_change(changeset, :folded_name, Names.fold(name))
    end
  end
end
