defmodule Zipfelschmaus.Catalog do
  @moduledoc """
  The household's articles and the shop areas they belong to (DECISIONS.md, 0005). Areas are
  seeded with a default order; a new article starts in "Sonstiges" until the language model
  guesses its area. An area set by hand applies on every list and stays.
  """

  import Ecto.Query

  require Logger

  alias Zipfelschmaus.Catalog.{Area, Article}
  alias Zipfelschmaus.{LanguageModel, Names, Repo}

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

  @doc """
  The article named `name`, and whether it was `:found` or `:created`; an unknown name becomes a
  new article in `area`, as set by hand, or without one in "Sonstiges".
  """
  def find_or_create_article(name, area \\ nil) when is_binary(name) do
    case get_article_by_name(name) do
      %Article{} = article ->
        {:ok, article, :found}

      nil ->
        with {:ok, article} <- create_article(name, area), do: {:ok, article, :created}
    end
  end

  @doc "Puts the article in `area` and marks the area as set by hand."
  def set_area_by_hand(%Article{} = article, %Area{} = area) do
    article
    |> Article.area_by_hand_changeset(area)
    |> Repo.update()
  end

  @doc """
  Has the language model guess the area of the article with `article_id` and puts it there,
  unless its area is set by hand, also while the model was thinking. Returns the moved article,
  or `:unchanged` when the model is not configured, fails or keeps the area.
  """
  def guess_area(article_id) do
    model = LanguageModel.impl()

    with true <- model.available?(),
         %Article{area_set_by_hand: false} = article <- Repo.get(Article, article_id),
         {:ok, area} <- ask_area(model, article.name) do
      put_guessed_area(article, area)
    else
      _unguessed -> :unchanged
    end
  end

  defp ask_area(model, name) do
    areas = list_areas()

    case model.answer(area_instructions(areas), name, area_schema(areas)) do
      {:ok, answer} ->
        area_in(answer, areas)

      {:error, reason} ->
        Logger.warning("the area model failed: #{inspect(reason)}")
        :error
    end
  end

  defp area_instructions(areas) do
    """
    You sort the shopping articles of a German household into the areas of a shop. The user \
    names an article; answer with the area where it is most likely found, one of: \
    #{Enum.map_join(areas, ", ", & &1.name)}.
    """
  end

  defp area_schema(areas) do
    %{
      type: "object",
      properties: %{area: %{type: "string", enum: Enum.map(areas, & &1.name)}},
      required: ["area"],
      additionalProperties: false
    }
  end

  defp area_in(answer, areas) do
    with {:ok, %{"area" => name}} <- JSON.decode(answer),
         %Area{} = area <- Enum.find(areas, &(&1.name == name)) do
      {:ok, area}
    else
      _off_schema ->
        Logger.warning("the area model answered off the schema")
        :error
    end
  end

  defp put_guessed_area(%Article{area_id: area_id}, %Area{id: area_id}), do: :unchanged

  defp put_guessed_area(article, area) do
    {count, _articles} =
      Repo.update_all(
        from(a in Article, where: a.id == ^article.id and not a.area_set_by_hand),
        set: [area_id: area.id, updated_at: DateTime.utc_now()]
      )

    if count == 1, do: {:ok, %{article | area_id: area.id, area: area}}, else: :unchanged
  end

  defp create_article(name, nil),
    do: insert_article(%Article{}, name, Repo.get_by!(Area, key: @fallback_area))

  defp create_article(name, %Area{} = area),
    do: insert_article(%Article{area_set_by_hand: true}, name, area)

  defp insert_article(article, name, area) do
    article
    |> Article.create_changeset(%{name: name, area_id: area.id})
    |> Repo.insert()
  end
end
