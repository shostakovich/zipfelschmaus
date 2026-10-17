defmodule Zipfelschmaus.ShoppingTest do
  use Zipfelschmaus.DataCase

  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.{Catalog, Shopping}
  alias Zipfelschmaus.Shopping.{Entry, ShoppingList}
  alias Zipfelschmaus.Users.Scope

  setup do
    anna = user_fixture()
    ben = user_fixture()
    %{anna: anna, ben: ben, as_anna: Scope.for_user(anna), as_ben: Scope.for_user(ben)}
  end

  describe "lists" do
    test "a new list belongs to its creator and is announced", %{anna: anna, as_anna: as_anna} do
      Shopping.subscribe_lists()

      {:ok, list} = Shopping.create_list(as_anna, %{name: "  Apotheke ", shared: false})

      assert %ShoppingList{name: "Apotheke", shared: false} = list
      assert list.owner_id == anna.id
      assert_receive {:list_changed, id} when id == list.id
    end

    test "a list needs a name of at most 60 characters", %{as_anna: as_anna} do
      assert {:error, changeset} = Shopping.create_list(as_anna, %{name: " "})
      assert %{name: ["muss ausgefüllt werden"]} = errors_on(changeset)

      assert {:error, changeset} =
               Shopping.create_list(as_anna, %{name: String.duplicate("x", 61)})

      assert %{name: ["darf höchstens 60 Zeichen lang sein"]} = errors_on(changeset)
    end

    test "a renamed list needs a name too", %{anna: anna, as_anna: as_anna} do
      list = list_fixture(anna, name: "DM")

      assert {:error, changeset} = Shopping.update_list(as_anna, list, %{"name" => ""})
      assert %{name: ["muss ausgefüllt werden"]} = errors_on(changeset)
    end

    test "a user sees their own lists and the shared ones, with their open entries",
         %{anna: anna, ben: ben, as_anna: as_anna, as_ben: as_ben} do
      supermarkt = list_fixture(anna, name: "Supermarkt", shared: true)
      apotheke = list_fixture(anna, name: "Apotheke", shared: false)
      baumarkt = list_fixture(ben, name: "Baumarkt", shared: false)
      entry_fixture(anna, supermarkt, "Milch")
      eggs = entry_fixture(anna, supermarkt, "Eier")
      Shopping.check_off(as_anna, eggs.id)

      assert anna_lists = Shopping.list_lists(as_anna)

      assert Enum.map(anna_lists, &{&1.name, &1.open_count}) == [
               {"Apotheke", 0},
               {"Supermarkt", 1}
             ]

      assert Enum.map(Shopping.list_lists(as_ben), & &1.name) == ["Baumarkt", "Supermarkt"]
      assert Shopping.get_list(as_ben, supermarkt.id).id == supermarkt.id
      assert Shopping.get_list(as_ben, apotheke.id) == nil
      assert Shopping.get_list(as_anna, baumarkt.id) == nil
    end

    test "only the owner gets a list for its settings",
         %{anna: anna, as_anna: as_anna, as_ben: as_ben} do
      list = list_fixture(anna, shared: true)

      assert Shopping.get_own_list(as_anna, list.id).id == list.id
      assert Shopping.get_own_list(as_ben, list.id) == nil
    end

    test "renaming and unsharing are announced on the list's topic",
         %{anna: anna, as_anna: as_anna, as_ben: as_ben} do
      list = list_fixture(anna, name: "DM", shared: true)
      Shopping.subscribe_list(list.id)

      {:ok, list} = Shopping.update_list(as_anna, list, %{name: "Drogerie", shared: false})

      assert %ShoppingList{name: "Drogerie", shared: false} = list
      assert_receive {:list_changed, id} when id == list.id
      assert Shopping.get_list(as_ben, list.id) == nil
    end

    test "deleting a list deletes its entries", %{anna: anna, as_anna: as_anna} do
      list = list_fixture(anna)
      entry = entry_fixture(anna, list, "Milch")
      Shopping.subscribe_list(list.id)

      {:ok, _list} = Shopping.delete_list(as_anna, list)

      assert Shopping.get_list(as_anna, list.id) == nil
      assert Repo.get(Entry, entry.id) == nil
      assert_receive {:list_changed, id} when id == list.id
    end
  end

  describe "add_entry/3" do
    setup %{anna: anna}, do: %{list: list_fixture(anna, shared: true)}

    test "puts a known article on the list and announces it",
         %{as_ben: as_ben, list: list} do
      Shopping.subscribe_list(list.id)

      {:ok, entry} = Shopping.add_entry(as_ben, list, %{name: "milch", detail: " 2 l "})

      assert %Entry{detail: "2 l", checked_off_at: nil} = entry
      assert %DateTime{} = entry.check_changed_at
      assert entry.article_id == Catalog.get_article_by_name("Milch").id
      assert_receive {:list_changed, id} when id == list.id
    end

    test ~s(creates an unknown article under "Sonstiges"), %{as_anna: as_anna, list: list} do
      {:ok, _entry} = Shopping.add_entry(as_anna, list, %{name: "Glitzerkonfetti"})

      assert [entry] = Shopping.list_open_entries(list)
      assert entry.article.name == "Glitzerkonfetti"
      assert entry.article.area.name == "Sonstiges"
      assert entry.detail == nil
    end

    test "adds no second entry for an article already on the list; the new detail wins",
         %{anna: anna, as_ben: as_ben, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l")

      {:ok, entry} = Shopping.add_entry(as_ben, list, %{name: "Milch", detail: "1 l Hafer"})

      assert entry.id == milk.id
      assert [%Entry{detail: "1 l Hafer"}] = Shopping.list_open_entries(list)
    end

    test "keeps the detail when none is given", %{anna: anna, as_anna: as_anna, list: list} do
      entry_fixture(anna, list, "Milch", "2 l")

      {:ok, _entry} = Shopping.add_entry(as_anna, list, %{name: "Milch", detail: "  "})

      assert [%Entry{detail: "2 l"}] = Shopping.list_open_entries(list)
    end

    test "opens a checked-off entry again", %{anna: anna, as_anna: as_anna, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l")
      {:ok, checked_off} = Shopping.check_off(as_anna, milk.id)

      {:ok, entry} = Shopping.add_entry(as_anna, list, %{name: "Milch", detail: "3 l"})

      assert entry.id == milk.id
      assert %Entry{checked_off_at: nil, detail: "3 l"} = entry
      assert DateTime.after?(entry.check_changed_at, checked_off.check_changed_at)
      assert Shopping.list_recent_entries(list) == []
    end

    test "refuses a missing name or an overlong detail", %{as_anna: as_anna, list: list} do
      assert {:error, changeset} = Shopping.add_entry(as_anna, list, %{name: " ", detail: "2 l"})
      assert %{name: ["muss ausgefüllt werden"]} = errors_on(changeset)

      assert {:error, changeset} =
               Shopping.add_entry(as_anna, list, %{
                 name: "Milch",
                 detail: String.duplicate("x", 81)
               })

      assert %{detail: ["darf höchstens 80 Zeichen lang sein"]} = errors_on(changeset)
    end

    test "adds nothing to a list the user does not see", %{ben: ben, as_anna: as_anna} do
      private = list_fixture(ben, shared: false)

      assert Shopping.add_entry(as_anna, private, %{name: "Milch"}) == {:error, :not_found}
      assert Shopping.list_open_entries(private) == []
    end
  end

  describe "the entries of a list" do
    setup %{anna: anna}, do: %{list: list_fixture(anna, shared: true)}

    test "open entries follow the list's area order, then the name",
         %{anna: anna, list: list} do
      for name <- ["Zahnpasta", "Milch", "Butter", "Äpfel", "Bananen"],
          do: entry_fixture(anna, list, name)

      assert list |> Shopping.list_open_entries() |> Enum.map(& &1.article.name) ==
               ["Äpfel", "Bananen", "Butter", "Milch", "Zahnpasta"]

      {:ok, list} = Shopping.move_area(Scope.for_user(anna), list, area_id("Kühlregal"), :up)
      {:ok, list} = Shopping.move_area(Scope.for_user(anna), list, area_id("Kühlregal"), :up)

      assert list |> Shopping.list_open_entries() |> Enum.map(& &1.article.name) ==
               ["Butter", "Milch", "Äpfel", "Bananen", "Zahnpasta"]
    end

    test ~s(a check-off moves the entry to "Zuletzt verwendet", newest first),
         %{anna: anna, as_ben: as_ben, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l")
      eggs = entry_fixture(anna, list, "Eier")
      Shopping.subscribe_list(list.id)

      {:ok, checked_off} = Shopping.check_off(as_ben, milk.id)
      {:ok, _eggs} = Shopping.check_off(as_ben, eggs.id)

      assert %DateTime{} = checked_off.checked_off_at
      assert checked_off.check_changed_at == checked_off.checked_off_at
      assert Shopping.list_open_entries(list) == []
      assert list |> Shopping.list_recent_entries() |> Enum.map(& &1.id) == [eggs.id, milk.id]

      assert [%Entry{detail: "2 l"}] =
               Enum.filter(Shopping.list_recent_entries(list), &(&1.id == milk.id))

      assert_receive {:list_changed, _id}
    end

    test "a put-back opens the entry again and keeps its detail",
         %{anna: anna, as_anna: as_anna, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l")
      {:ok, checked_off} = Shopping.check_off(as_anna, milk.id)

      {:ok, entry} = Shopping.put_back(as_anna, milk.id)

      assert %Entry{checked_off_at: nil, detail: "2 l"} = entry
      assert DateTime.after?(entry.check_changed_at, checked_off.check_changed_at)
      assert [%Entry{id: id}] = Shopping.list_open_entries(list)
      assert id == milk.id
    end

    test "checking off twice keeps the first time", %{anna: anna, as_anna: as_anna, list: list} do
      milk = entry_fixture(anna, list, "Milch")
      {:ok, first} = Shopping.check_off(as_anna, milk.id)

      {:ok, second} = Shopping.check_off(as_anna, milk.id)

      assert second.checked_off_at == first.checked_off_at
      assert second.check_changed_at == first.check_changed_at
    end

    test ~s("Zuletzt verwendet" holds at most 30 entries), %{
      anna: anna,
      as_anna: as_anna,
      list: list
    } do
      for article <- Enum.take(Catalog.list_articles(), 31) do
        entry = entry_fixture(anna, list, article.name)
        Shopping.check_off(as_anna, entry.id)
      end

      assert length(Shopping.list_recent_entries(list)) == 30
    end

    test "entries of a list the user does not see stay as they are",
         %{ben: ben, as_anna: as_anna} do
      private = list_fixture(ben, shared: false)
      milk = entry_fixture(ben, private, "Milch")

      assert Shopping.check_off(as_anna, milk.id) == {:error, :not_found}
      assert Shopping.put_back(as_anna, milk.id) == {:error, :not_found}
      assert [_open] = Shopping.list_open_entries(private)
    end
  end

  describe "area order" do
    setup %{anna: anna}, do: %{list: list_fixture(anna, shared: true)}

    test "a new list copies the default area order", %{list: list} do
      default = Enum.map(Catalog.list_areas(), & &1.id)

      assert list.area_order == default
      assert Enum.map(Shopping.list_areas(list), & &1.id) == default
    end

    test "the owner moves an area up and down, announced on the list's topic",
         %{as_anna: as_anna, list: list} do
      default = area_names(list)
      index = Enum.find_index(default, &(&1 == "Drogerie"))
      Shopping.subscribe_list(list.id)

      {:ok, list} = Shopping.move_area(as_anna, list, area_id("Drogerie"), :up)

      assert_receive {:list_changed, id} when id == list.id
      assert Enum.at(area_names(list), index - 1) == "Drogerie"
      assert Enum.at(area_names(list), index) == Enum.at(default, index - 1)

      {:ok, list} = Shopping.move_area(as_anna, list, area_id("Drogerie"), :down)

      assert area_names(list) == default
      assert Shopping.get_list(as_anna, list.id).area_order == list.area_order
    end

    test "the first area does not move up, the last not down", %{as_anna: as_anna, list: list} do
      [first | _] = names = area_names(list)
      last = List.last(names)

      {:ok, list} = Shopping.move_area(as_anna, list, area_id(first), :up)
      {:ok, list} = Shopping.move_area(as_anna, list, area_id(last), :down)

      assert area_names(list) == names
    end

    test "each list keeps its own order", %{anna: anna, as_anna: as_anna, list: list} do
      other = list_fixture(anna, name: "Bioladen")

      {:ok, _list} = Shopping.move_area(as_anna, list, area_id("Kühlregal"), :up)

      assert Enum.take(area_names(other), 3) ==
               ["Obst und Gemüse", "Brot und Backwaren", "Kühlregal"]
    end

    test "an area the list does not know yet comes last", %{list: list} do
      [first | rest] = list.area_order
      list = %{list | area_order: rest}

      assert List.last(Shopping.list_areas(list)).id == first
    end

    test "only the owner changes the area order", %{as_ben: as_ben, list: list} do
      assert Shopping.move_area(as_ben, list, area_id("Drogerie"), :up) == {:error, :not_found}
      assert Shopping.get_list(as_ben, list.id).area_order == list.area_order
    end
  end

  describe "editing an entry" do
    setup %{anna: anna}, do: %{list: list_fixture(anna, shared: true)}

    test "changes its detail; a blank one removes it",
         %{anna: anna, as_ben: as_ben, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l")
      Shopping.subscribe_list(list.id)

      {:ok, entry} = Shopping.update_detail(as_ben, milk.id, %{detail: " 3 l "})
      assert entry.detail == "3 l"
      assert_receive {:list_changed, id} when id == list.id

      {:ok, entry} = Shopping.update_detail(as_ben, milk.id, %{detail: "  "})
      assert entry.detail == nil
    end

    test "refuses an overlong detail", %{anna: anna, as_anna: as_anna, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l")

      assert {:error, changeset} =
               Shopping.update_detail(as_anna, milk.id, %{detail: String.duplicate("x", 81)})

      assert %{detail: ["darf höchstens 80 Zeichen lang sein"]} = errors_on(changeset)
    end

    test "an area set by hand moves the article on every list and stays",
         %{anna: anna, ben: ben, as_ben: as_ben, list: list} do
      private = list_fixture(anna, name: "DM", shared: false)
      tabs = entry_fixture(anna, list, "Spülmaschinentabs")
      entry_fixture(anna, private, "Spülmaschinentabs")
      Shopping.subscribe_list(private.id)

      {:ok, article} = Shopping.set_area(as_ben, tabs.id, area_id("Haushalt"))

      assert article.area_set_by_hand
      assert_receive {:list_changed, id} when id == private.id

      for l <- [list, private],
          do: assert([%{article: %{area: %{name: "Haushalt"}}}] = Shopping.list_open_entries(l))

      ben_list = list_fixture(ben, name: "Baumarkt")
      entry = entry_fixture(ben, ben_list, "spülmaschinentabs")
      assert Shopping.get_entry(as_ben, entry.id).article.area.name == "Haushalt"
    end

    test "entries of a list the user does not see stay as they are",
         %{ben: ben, as_anna: as_anna} do
      private = list_fixture(ben, shared: false)
      milk = entry_fixture(ben, private, "Milch", "2 l")

      assert Shopping.get_entry(as_anna, milk.id) == nil
      assert Shopping.update_detail(as_anna, milk.id, %{detail: "3 l"}) == {:error, :not_found}
      assert Shopping.set_area(as_anna, milk.id, area_id("Haushalt")) == {:error, :not_found}

      assert [%{detail: "2 l", article: %{area: %{name: "Kühlregal"}}}] =
               Shopping.list_open_entries(private)
    end

    test "an unknown area is refused", %{anna: anna, as_anna: as_anna, list: list} do
      milk = entry_fixture(anna, list, "Milch")

      assert Shopping.set_area(as_anna, milk.id, -1) == {:error, :not_found}
    end
  end

  describe "sync_check_states/2" do
    setup %{anna: anna} do
      list = list_fixture(anna, shared: true)
      milk = entry_fixture(anna, list, "Milch") |> changed_at(minutes_ago(20))
      %{list: list, milk: milk}
    end

    test "applies a change newer than the entry's last check-state change, announced once",
         %{as_ben: as_ben, list: list, milk: milk} do
      checked_off_at = minutes_ago(10)
      put_back_at = minutes_ago(5)
      Shopping.subscribe_list(list.id)

      :ok = Shopping.sync_check_states(as_ben, [sync(milk, true, checked_off_at)])

      assert %Entry{checked_off_at: ^checked_off_at, check_changed_at: ^checked_off_at} =
               Repo.get!(Entry, milk.id)

      :ok = Shopping.sync_check_states(as_ben, [sync(milk, false, put_back_at)])

      assert %Entry{checked_off_at: nil, check_changed_at: ^put_back_at} =
               Repo.get!(Entry, milk.id)

      assert_receive {:list_changed, id} when id == list.id
      assert_receive {:list_changed, id} when id == list.id
      refute_receive {:list_changed, _id}
    end

    test "drops a change older than the entry's last check-state change",
         %{as_anna: as_anna, milk: milk} do
      {:ok, _checked_off} = Shopping.check_off(as_anna, milk.id)
      {:ok, _open} = Shopping.put_back(as_anna, milk.id)
      milk = Repo.get!(Entry, milk.id)

      :ok = Shopping.sync_check_states(as_anna, [sync(milk, true, minutes_ago(1))])

      assert Repo.get!(Entry, milk.id) == milk
    end

    test "a change to the state the entry has keeps its time", %{as_anna: as_anna, milk: milk} do
      :ok = Shopping.sync_check_states(as_anna, [sync(milk, false, minutes_ago(1))])

      assert Repo.get!(Entry, milk.id) == milk
    end

    test "a time in the future counts as now", %{as_anna: as_anna, milk: milk} do
      started = DateTime.utc_now()

      :ok = Shopping.sync_check_states(as_anna, [sync(milk, true, minutes_ago(-60))])

      assert %Entry{checked_off_at: at, check_changed_at: at} = Repo.get!(Entry, milk.id)
      assert DateTime.compare(at, started) != :lt
      assert DateTime.compare(at, DateTime.utc_now()) != :gt
    end

    test "applies the changes in order", %{as_anna: as_anna, milk: milk} do
      :ok =
        Shopping.sync_check_states(as_anna, [
          sync(milk, true, minutes_ago(3)),
          sync(milk, false, minutes_ago(2))
        ])

      assert Entry.open?(Repo.get!(Entry, milk.id))
    end

    test "leaves entries of lists the user does not see and unknown entries",
         %{ben: ben, as_anna: as_anna} do
      private = list_fixture(ben, shared: false)
      eggs = entry_fixture(ben, private, "Eier") |> changed_at(minutes_ago(20))

      :ok =
        Shopping.sync_check_states(as_anna, [
          sync(eggs, true, minutes_ago(1)),
          %{entry_id: -1, checked_off?: true, at: minutes_ago(1)}
        ])

      assert Entry.open?(Repo.get!(Entry, eggs.id))
    end
  end

  defp sync(entry, checked_off?, at),
    do: %{entry_id: entry.id, checked_off?: checked_off?, at: at}

  defp minutes_ago(minutes), do: DateTime.add(DateTime.utc_now(), -minutes, :minute)

  defp changed_at(entry, at),
    do: entry |> Ecto.Changeset.change(check_changed_at: at) |> Repo.update!()

  defp area_id(name), do: Enum.find(Catalog.list_areas(), &(&1.name == name)).id

  defp area_names(list), do: Enum.map(Shopping.list_areas(list), & &1.name)
end
