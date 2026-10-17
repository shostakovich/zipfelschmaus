defmodule Zipfelschmaus.Catalog do
  @moduledoc """
  The household's articles and the shop areas they belong to (DECISIONS.md, 0005). Areas are
  seeded with a default order; a new article starts in "Sonstiges". An area set by hand applies on
  every list and stays.
  """

  import Ecto.Query

  alias Zipfelschmaus.Catalog.{Area, Article}
  alias Zipfelschmaus.{Names, Repo}

  @fallback_area "sonstiges"

  @doc "The areas in their default order."
  def list_areas, do: Repo.all(from a in Area, order_by: [a.position, a.id])

  @doc "The area with `id`, or nil."
  def get_area(id), do: Repo.get(Area, id)

  @doc "All articles by name."
  def list_articles, do: Article |> Repo.all() |> Enum.sort_by(&Names.sort_key(&1.name))

  @doc "The article named `name`, regardless of case and spacing, or nil."
  def get_article_by_name(name) when is_binary(name),
    do: Repo.get_by(Article, folded_name: Names.fold(name))

  @doc ~s(The article named `name`; an unknown name becomes a new article in "Sonstiges".)
  def find_or_create_article(name) when is_binary(name) do
    case get_article_by_name(name) do
      %Article{} = article -> {:ok, article}
      nil -> create_article(name)
    end
  end

  @doc "Puts the article in `area` and marks the area as set by hand."
  def set_area_by_hand(%Article{} = article, %Area{} = area) do
    article
    |> Article.area_by_hand_changeset(area)
    |> Repo.update()
  end

  defp create_article(name) do
    area = Repo.get_by!(Area, key: @fallback_area)

    %Article{}
    |> Article.create_changeset(%{name: name, area_id: area.id})
    |> Repo.insert()
  end
end
