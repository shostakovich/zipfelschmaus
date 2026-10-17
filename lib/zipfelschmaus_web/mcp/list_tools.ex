defmodule ZipfelschmausWeb.MCP.ListTools do
  @moduledoc """
  The tools on lists, entries and areas. They go through `Zipfelschmaus.Shopping` with the
  connector user's scope, as the app does, so they see what that user sees. Objects are keyword
  lists, so the keys keep a readable order; fields without a value are left out.
  """

  alias Zipfelschmaus.{Catalog, Names, Shopping}
  alias Zipfelschmaus.Catalog.Area
  alias Zipfelschmaus.Shopping.{Entry, ShoppingList}
  alias ZipfelschmausWeb.CoreComponents
  alias ZipfelschmausWeb.MCP.ToolError

  @max_entries 100

  @doc "The most entries `add_entries/2` adds in one call."
  def max_entries, do: @max_entries

  def list_lists(_args, scope) do
    [
      lists:
        Enum.map(Shopping.list_lists(scope), &(list(&1, scope) ++ [open_entries: &1.open_count]))
    ]
  end

  def read_list(args, scope) do
    list = list!(scope, args.list_id)

    list(list, scope) ++
      [
        open_entries: Enum.map(Shopping.list_open_entries(list), &entry/1),
        recently_used: Enum.map(Shopping.list_recent_entries(list), &entry/1)
      ]
  end

  def list_areas(_args, _scope), do: [areas: Enum.map(Catalog.list_areas(), & &1.name)]

  def add_entries(args, scope) do
    if length(args.entries) > @max_entries,
      do: ToolError.raise!("At most #{@max_entries} entries per call.")

    list = list!(scope, args.list_id)
    areas = Catalog.list_areas()
    entries = Enum.map(args.entries, &new_entry!(&1, areas))

    [list: list.name, added: Enum.map(entries, &add!(scope, list, &1))]
  end

  defp new_entry!(%{article: name, detail: detail, area: area}, areas) do
    changeset = Shopping.change_new_entry(%{name: name, detail: detail})

    if not changeset.valid?,
      do: ToolError.raise!(refused("the article #{inspect(name)}", changeset))

    %{name: name, detail: detail, area: area && area!(areas, area)}
  end

  defp add!(scope, list, %{name: name, area: area} = new_entry) do
    case Shopping.add_entry(scope, list, Map.take(new_entry, [:name, :detail]), area) do
      {:ok, entry, article_was} ->
        entry(Shopping.get_entry(scope, entry.id)) ++
          if(article_was == :created, do: [new_article: true], else: [])

      {:error, _reason} ->
        ToolError.raise!("Could not add #{inspect(name)}; the entries before it were added.")
    end
  end

  def check_off(args, scope), do: change_check_state(args.entry_ids, scope, &Shopping.check_off/2)
  def put_back(args, scope), do: change_check_state(args.entry_ids, scope, &Shopping.put_back/2)

  defp change_check_state(entry_ids, scope, change) do
    entry_ids = Enum.uniq(entry_ids)
    Enum.each(entry_ids, &entry!(scope, &1))

    [
      entries:
        Enum.map(entry_ids, fn entry_id ->
          {:ok, entry} = change.(scope, entry_id)
          entry(entry)
        end)
    ]
  end

  def create_list(args, scope) do
    case Shopping.create_list(scope, %{name: args.name, shared: args.shared}) do
      {:ok, list} -> list(list, scope)
      {:error, changeset} -> ToolError.raise!(refused("the list", changeset))
    end
  end

  def set_article_area(args, scope) do
    article =
      Catalog.get_article_by_name(args.article) ||
        ToolError.raise!("Unknown article #{inspect(args.article)}.")

    area = area!(Catalog.list_areas(), args.area)
    {:ok, article} = Shopping.set_article_area(scope, article, area)
    [article: article.name, area: area.name]
  end

  defp list!(scope, list_id) do
    Shopping.get_list(scope, list_id) ||
      ToolError.raise!(
        "Unknown list #{list_id}: call list_lists for the ids of the lists you see."
      )
  end

  defp entry!(scope, entry_id) do
    Shopping.get_entry(scope, entry_id) ||
      ToolError.raise!(
        "Unknown entry #{entry_id}: call read_list for the ids of a list's entries."
      )
  end

  defp area!(areas, name) do
    Enum.find(areas, &(Names.fold(&1.name) == Names.fold(name))) ||
      ToolError.raise!(
        "Unknown area #{inspect(name)}. Available: #{Enum.map_join(areas, ", ", & &1.name)}."
      )
  end

  defp list(%ShoppingList{} = list, scope) do
    [id: list.id, name: list.name, shared: list.shared, mine: list.owner_id == scope.user.id]
  end

  defp entry(%Entry{article: %{area: %Area{} = area} = article} = entry) do
    compact(
      id: entry.id,
      article: article.name,
      detail: entry.detail,
      area: area.name,
      checked_off_at: entry.checked_off_at && moment(entry.checked_off_at)
    )
  end

  defp moment(utc), do: utc |> DateTime.truncate(:second) |> DateTime.to_iso8601()

  defp compact(fields), do: Enum.reject(fields, fn {_key, value} -> is_nil(value) end)

  defp refused(what, changeset),
    do: "The app refused #{what} (message in German): " <> errors(changeset)

  defp errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(&CoreComponents.translate_error/1)
    |> Enum.map_join("; ", fn {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}" end)
  end
end
