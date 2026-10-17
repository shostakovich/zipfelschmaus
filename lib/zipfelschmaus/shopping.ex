defmodule Zipfelschmaus.Shopping do
  @moduledoc """
  Shopping lists and their entries, as the signed-in user of a scope sees them: their own lists
  and those shared with the household. Only the owner changes a list's settings; everyone who
  sees it adds, checks off and puts back entries.

  After every change `{:list_changed, list_id}` goes out on the topic `"lists"` and on the
  list's own topic; it carries no content, so a subscriber reloads what its scope may see.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Phoenix.PubSub
  alias Zipfelschmaus.{Catalog, Names, Repo}
  alias Zipfelschmaus.Shopping.{Entry, ShoppingList}
  alias Zipfelschmaus.Users.Scope

  @recent_limit 30

  @doc "Subscribes the caller to the changes of all lists, for overviews."
  def subscribe_lists, do: PubSub.subscribe(Zipfelschmaus.PubSub, "lists")

  @doc "Subscribes the caller to the changes of one list."
  def subscribe_list(list_id), do: PubSub.subscribe(Zipfelschmaus.PubSub, list_topic(list_id))

  defp broadcast(list_id) do
    for topic <- ["lists", list_topic(list_id)],
        do: PubSub.broadcast(Zipfelschmaus.PubSub, topic, {:list_changed, list_id})

    :ok
  end

  defp list_topic(list_id), do: "list:#{list_id}"

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

  def create_list(%Scope{user: user}, attrs) do
    %ShoppingList{owner_id: user.id}
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

  defp tap_broadcast({:ok, %ShoppingList{id: id}} = result) do
    broadcast(id)
    result
  end

  defp tap_broadcast({:ok, %Entry{list_id: list_id}} = result) do
    broadcast(list_id)
    result
  end

  defp tap_broadcast(error), do: error

  @doc "The open entries with article and area, in the default area order, then by name."
  def list_open_entries(%ShoppingList{id: list_id}) do
    Repo.all(
      from e in Entry,
        join: a in assoc(e, :article),
        join: ar in assoc(a, :area),
        where: e.list_id == ^list_id and is_nil(e.checked_off_at),
        preload: [article: {a, area: ar}]
    )
    |> Enum.sort_by(&{&1.article.area.position, Names.sort_key(&1.article.name)})
  end

  @doc ~s("Zuletzt verwendet": the newest #{@recent_limit} checked-off entries with article and area.)
  def list_recent_entries(%ShoppingList{id: list_id}) do
    Repo.all(
      from e in Entry,
        join: a in assoc(e, :article),
        join: ar in assoc(a, :area),
        where: e.list_id == ^list_id and not is_nil(e.checked_off_at),
        order_by: [desc: e.checked_off_at, desc: e.id],
        limit: @recent_limit,
        preload: [article: {a, area: ar}]
    )
  end

  @doc "A changeset for the form that adds an article by name with an optional detail."
  def change_new_entry(attrs \\ %{}) do
    {%{}, %{name: :string, detail: :string}}
    |> Changeset.cast(attrs, [:name, :detail])
    |> Changeset.update_change(:detail, &String.trim/1)
    |> Changeset.validate_required([:name])
    |> Changeset.validate_length(:name, max: 80)
    |> Changeset.validate_length(:detail, max: 80)
  end

  @doc """
  Puts the article named `name` on the list, creating an unknown article. An article that is
  already on the list is not added twice: its entry is opened again and takes the new detail; a
  blank detail keeps the one it has.
  """
  def add_entry(%Scope{} = scope, %ShoppingList{} = list, attrs) do
    with {:ok, input} <- Changeset.apply_action(change_new_entry(attrs), :insert),
         %ShoppingList{} = list <- get_list(scope, list.id) || {:error, :not_found} do
      Repo.transact(fn -> put_article(list, input.name, input[:detail]) end)
      |> tap_broadcast()
    end
  end

  defp put_article(list, name, detail) do
    with {:ok, article} <- Catalog.find_or_create_article(name),
         do: put_entry(list, article, detail)
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

  defp set_checked_off(changeset, entry, checked_off?, now) do
    if Entry.open?(entry) == checked_off?,
      do:
        Changeset.change(changeset,
          checked_off_at: if(checked_off?, do: now),
          check_changed_at: now
        ),
      else: changeset
  end

  defp get_entry(scope, entry_id) do
    Repo.one(
      from e in Entry,
        join: l in subquery(visible(scope)),
        on: l.id == e.list_id,
        where: e.id == ^entry_id
    )
  end
end
