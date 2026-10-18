defmodule Zipfelschmaus.Shopping do
  @moduledoc """
  Shopping lists and their entries, as the signed-in user of a scope sees them: their own lists
  and those shared with the household. Only the owner changes a list's settings and area order;
  everyone who sees it adds, edits, checks off and puts back entries.

  After every change `{:list_changed, list_id}` goes out on the topic `"lists"`; it carries no
  content, so a subscriber reloads what its scope may see.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Phoenix.PubSub
  alias Zipfelschmaus.{Catalog, Names, Repo}
  alias Zipfelschmaus.Catalog.{Area, Article}
  alias Zipfelschmaus.Shopping.{AreaGuesses, Entry, ShoppingList}
  alias Zipfelschmaus.Users.Scope

  @recent_limit 30

  @doc "Subscribes the caller to the changes of all lists."
  def subscribe_lists, do: PubSub.subscribe(Zipfelschmaus.PubSub, "lists")

  defp broadcast(list_id),
    do: PubSub.broadcast(Zipfelschmaus.PubSub, "lists", {:list_changed, list_id})

  defp visible(%Scope{user: user}),
    do: from(l in ShoppingList, where: l.owner_id == ^user.id or l.shared)

  @doc "The lists the user sees, by name, each with its number of open entries."
  def list_lists(%Scope{} = scope) do
    open_counts =
      from e in Entry,
        where: is_nil(e.checked_off_at),
        group_by: e.list_id,
        select: %{list_id: e.list_id, count: count(e.id)}

    Repo.all(
      from l in visible(scope),
        left_join: c in subquery(open_counts),
        on: c.list_id == l.id,
        order_by: l.id,
        select_merge: %{open_count: coalesce(c.count, 0)}
    )
    |> Enum.sort_by(&Names.sort_key(&1.name))
  end

  @doc "The list with `id` if the user sees it, otherwise nil."
  def get_list(%Scope{} = scope, id), do: Repo.get(visible(scope), id)

  @doc "The list with `id` if the user owns it, otherwise nil."
  def get_own_list(%Scope{user: user}, id),
    do: Repo.get_by(ShoppingList, id: id, owner_id: user.id)

  @doc "A changeset for the list's settings form."
  def change_list(%ShoppingList{} = list, attrs \\ %{}), do: ShoppingList.changeset(list, attrs)

  @doc "Creates a list with the default area order."
  def create_list(%Scope{user: user}, attrs) do
    %ShoppingList{owner_id: user.id, area_order: Enum.map(Catalog.list_areas(), & &1.id)}
    |> ShoppingList.changeset(attrs)
    |> Repo.insert()
    |> tap_broadcast()
  end

  def update_list(%Scope{user: %{id: owner_id}}, %ShoppingList{owner_id: owner_id} = list, attrs) do
    list
    |> ShoppingList.changeset(attrs)
    |> Repo.update()
    |> tap_broadcast()
  end

  @doc "Deletes the list with its entries."
  def delete_list(%Scope{user: %{id: owner_id}}, %ShoppingList{owner_id: owner_id} = list) do
    list |> Repo.delete() |> tap_broadcast()
  end

  @doc "The areas in the list's area order; an area the list does not know yet comes last."
  def list_areas(%ShoppingList{} = list), do: Enum.sort_by(Catalog.list_areas(), area_rank(list))

  @doc "Moves the area one place `:up` or `:down` in the area order of the user's own list."
  def move_area(%Scope{} = scope, %ShoppingList{} = list, area_id, direction)
      when direction in [:up, :down] do
    with %ShoppingList{} = list <- get_own_list(scope, list.id) || {:error, :not_found} do
      area_order = list |> list_areas() |> Enum.map(& &1.id) |> move(area_id, direction)

      list
      |> Changeset.change(area_order: area_order)
      |> Repo.update()
      |> tap_broadcast()
    end
  end

  defp move(ids, id, direction) do
    case Enum.find_index(ids, &(&1 == id)) do
      nil -> ids
      index -> swap(ids, index, if(direction == :up, do: index - 1, else: index + 1))
    end
  end

  defp swap(ids, index, other) when other >= 0 and other < length(ids) do
    ids
    |> List.replace_at(index, Enum.at(ids, other))
    |> List.replace_at(other, Enum.at(ids, index))
  end

  defp swap(ids, _index, _other), do: ids

  defp area_rank(%ShoppingList{area_order: area_order}) do
    ranks = area_order |> Enum.with_index() |> Map.new()
    fn %Area{id: id, position: position} -> {Map.get(ranks, id, length(area_order)), position} end
  end

  defp tap_broadcast({:ok, %ShoppingList{id: id}} = result) do
    broadcast(id)
    result
  end

  defp tap_broadcast({:ok, %Entry{list_id: list_id}} = result) do
    broadcast(list_id)
    result
  end

  defp tap_broadcast(error), do: error

  @doc "The open entries with article and area, in the list's area order, then by name."
  def list_open_entries(%ShoppingList{id: list_id} = list) do
    rank = area_rank(list)

    Repo.all(
      from e in with_article(Entry), where: e.list_id == ^list_id and is_nil(e.checked_off_at)
    )
    |> Enum.sort_by(&{rank.(&1.article.area), Names.sort_key(&1.article.name)})
  end

  @doc ~s("Zuletzt verwendet": the newest #{@recent_limit} checked-off entries with article and area.)
  def list_recent_entries(%ShoppingList{id: list_id}) do
    Repo.all(
      from e in with_article(Entry),
        where: e.list_id == ^list_id and not is_nil(e.checked_off_at),
        order_by: [desc: e.checked_off_at, desc: e.id],
        limit: @recent_limit
    )
  end

  @doc "A changeset for the form that adds an article by name with an optional detail."
  def change_new_entry(attrs \\ %{}) do
    {%{}, %{name: :string, detail: :string}}
    |> Changeset.cast(attrs, [:name, :detail])
    |> Changeset.validate_required([:name])
    |> Article.validate_name()
    |> Entry.validate_detail()
  end

  @doc """
  Puts the article named `name` on the list and returns the entry with its article, and whether
  the article was `:found` or `:created`. An unknown article is created in `area`, as set by
  hand, or without one in "Sonstiges", its area then guessed in the background; a known article
  keeps its area. An article that is already on the list is not added twice: its entry is
  opened again and takes the new detail; a blank detail keeps the one it has.
  """
  def add_entry(%Scope{} = scope, %ShoppingList{} = list, attrs, area \\ nil) do
    with {:ok, input} <- Changeset.apply_action(change_new_entry(attrs), :insert),
         %ShoppingList{} = list <- get_list(scope, list.id) || {:error, :not_found},
         {:ok, {entry, article_was}} <-
           Repo.transact(fn -> put_article(list, input.name, input[:detail], area) end) do
      broadcast(entry.list_id)
      if article_was == :created and is_nil(area), do: AreaGuesses.enqueue(entry.article_id)
      {:ok, entry, article_was}
    end
  end

  defp put_article(list, name, detail, area) do
    with {:ok, article, article_was} <- Catalog.find_or_create_article(name, area),
         {:ok, entry} <- put_entry(list, article, detail),
         do: {:ok, {%{entry | article: article}, article_was}}
  end

  defp put_entry(list, article, detail) do
    now = DateTime.utc_now()

    case Repo.get_by(Entry, list_id: list.id, article_id: article.id) do
      nil ->
        Repo.insert(%Entry{
          list_id: list.id,
          article_id: article.id,
          detail: detail,
          check_changed_at: now
        })

      entry ->
        entry
        |> Changeset.change(detail: detail || entry.detail)
        |> set_checked_off(entry, false, now)
        |> Repo.update()
    end
  end

  @doc ~s(Checks off the entry: it moves to "Zuletzt verwendet".)
  def check_off(%Scope{} = scope, entry_id), do: change_check_state(scope, entry_id, true)

  @doc "Puts a checked-off entry back on the list."
  def put_back(%Scope{} = scope, entry_id), do: change_check_state(scope, entry_id, false)

  defp change_check_state(scope, entry_id, checked_off?) do
    case get_entry(scope, entry_id) do
      nil ->
        {:error, :not_found}

      entry ->
        entry
        |> Changeset.change()
        |> set_checked_off(entry, checked_off?, DateTime.utc_now())
        |> Repo.update()
        |> tap_broadcast()
    end
  end

  @doc """
  Applies check-offs and put-backs made offline, in order, each at the time it happened on the
  device: a change newer than its entry's last check-state change wins, an older one is
  dropped, as is one to an entry the user does not see. A time in the future counts as now.
  """
  def sync_check_states(%Scope{} = scope, changes) do
    now = DateTime.utc_now()

    {:ok, list_ids} =
      Repo.transact(fn ->
        {:ok, changes |> Enum.flat_map(&sync_check_state(scope, &1, now)) |> Enum.uniq()}
      end)

    Enum.each(list_ids, &broadcast/1)
  end

  defp sync_check_state(scope, %{entry_id: entry_id, checked_off?: checked_off?, at: at}, now) do
    at = Enum.min([at, now], DateTime)

    with %Entry{} = entry <- get_entry(scope, entry_id),
         :gt <- DateTime.compare(at, entry.check_changed_at),
         %Changeset{changes: changes} = changeset when changes != %{} <-
           entry |> Changeset.change() |> set_checked_off(entry, checked_off?, at) do
      Repo.update!(changeset)
      [entry.list_id]
    else
      _unchanged -> []
    end
  end

  defp set_checked_off(changeset, entry, checked_off?, now) do
    if Entry.open?(entry) == checked_off?,
      do:
        Changeset.change(changeset,
          checked_off_at: if(checked_off?, do: now),
          check_changed_at: now
        ),
      else: changeset
  end

  @doc "A changeset for the form that changes an entry's detail."
  def change_detail(%Entry{} = entry, attrs \\ %{}), do: Entry.detail_changeset(entry, attrs)

  @doc "Changes the entry's detail; a blank one removes it."
  def update_detail(%Scope{} = scope, entry_id, attrs) do
    case get_entry(scope, entry_id) do
      nil -> {:error, :not_found}
      entry -> entry |> Entry.detail_changeset(attrs) |> Repo.update() |> tap_broadcast()
    end
  end

  @doc "Sets the area of the entry's article by hand; the article moves on every list."
  def set_area(%Scope{} = scope, entry_id, area_id) do
    with %Entry{} = entry <- get_entry(scope, entry_id) || {:error, :not_found},
         %Area{} = area <- Catalog.get_area(area_id) || {:error, :not_found},
         do: set_article_area(scope, entry.article, area)
  end

  @doc "Sets the article's area by hand; it moves on every list."
  def set_article_area(%Scope{}, %Article{} = article, %Area{} = area) do
    with {:ok, article} <- Catalog.set_area_by_hand(article, area) do
      broadcast_article(article.id)
      {:ok, article}
    end
  end

  @doc """
  Guesses the area of the article with `article_id`, see `Catalog.guess_area/1`, and announces a
  move to every list holding it.
  """
  def guess_area(article_id) do
    with {:ok, article} <- Catalog.guess_area(article_id) do
      broadcast_article(article.id)
      {:ok, article}
    end
  end

  defp broadcast_article(article_id) do
    from(e in Entry, where: e.article_id == ^article_id, select: e.list_id)
    |> Repo.all()
    |> Enum.each(&broadcast/1)
  end

  @doc "The entry with `id`, its article and area, if the user sees its list; otherwise nil."
  def get_entry(%Scope{} = scope, entry_id) do
    Repo.one(
      from e in with_article(Entry),
        join: l in subquery(visible(scope)),
        on: l.id == e.list_id,
        where: e.id == ^entry_id
    )
  end

  defp with_article(query) do
    from e in query,
      join: a in assoc(e, :article),
      join: ar in assoc(a, :area),
      preload: [article: {a, area: ar}]
  end
end
