defmodule ZipfelschmausWeb.MCPListsTest do
  use ZipfelschmausWeb.MCPCase

  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.{Catalog, FakeLanguageModel, Repo, Shopping}
  alias Zipfelschmaus.Shopping.AreaGuesses
  alias Zipfelschmaus.Users.Scope

  setup do
    anna = user_fixture()
    ben = user_fixture()
    %{anna: anna, ben: ben, as_anna: mcp_path(anna), as_ben: mcp_path(ben)}
  end

  test "adding an entry for a new article creates the article and the entry",
       %{anna: anna, as_anna: as_anna} do
    FakeLanguageModel.stub(fn "Spülmaschinentabs" -> {:ok, ~s({"area":"Drogerie"})} end)
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    Shopping.subscribe_lists()

    added =
      ok(as_anna, "add_entries", %{
        "list_id" => list.id,
        "entries" => [%{"article" => "Spülmaschinentabs", "detail" => "1 Packung"}]
      })

    assert %{
             "list" => "Supermarkt",
             "added" => [
               %{
                 "article" => "Spülmaschinentabs",
                 "detail" => "1 Packung",
                 "area" => "Sonstiges",
                 "new_article" => true
               }
             ]
           } = added

    assert_receive {:list_changed, id} when id == list.id
    :sys.get_state(AreaGuesses)

    assert [%{detail: "1 Packung", article: %{name: "Spülmaschinentabs", area: area}}] =
             Shopping.list_open_entries(list)

    assert area.name == "Drogerie"
  end

  test "adding an existing open article updates its detail", %{anna: anna, as_anna: as_anna} do
    list = list_fixture(anna, name: "Supermarkt")
    milk = entry_fixture(anna, list, "Milch", "2 l")

    added =
      ok(as_anna, "add_entries", %{
        "list_id" => list.id,
        "entries" => [%{"article" => "milch", "detail" => "1 l Hafer"}]
      })

    assert added["added"] == [
             %{
               "id" => milk.id,
               "article" => "Milch",
               "detail" => "1 l Hafer",
               "area" => "Kühlregal"
             }
           ]

    assert [%{id: id, detail: "1 l Hafer"}] = Shopping.list_open_entries(list)
    assert id == milk.id
  end

  test "an area given for a new article is set by hand and the guess is dropped",
       %{anna: anna, as_anna: as_anna} do
    FakeLanguageModel.stub(fn _name -> {:ok, ~s({"area":"Drogerie"})} end)
    list = list_fixture(anna)

    added =
      ok(as_anna, "add_entries", %{
        "list_id" => list.id,
        "entries" => [
          %{"article" => "Spülmaschinentabs", "area" => "haushalt"},
          %{"article" => "Milch", "area" => "Getränke"}
        ]
      })

    assert [%{"area" => "Haushalt", "new_article" => true}, %{"area" => "Kühlregal"} = milk] =
             added["added"]

    refute Map.has_key?(milk, "new_article")
    :sys.get_state(AreaGuesses)

    assert %{area_set_by_hand: true} = tabs = Catalog.get_article_by_name("Spülmaschinentabs")
    assert Catalog.get_area(tabs.area_id).name == "Haushalt"
  end

  test "a connector sees its user's lists and the shared ones, never the other's private ones",
       %{anna: anna, ben: ben, as_anna: as_anna, as_ben: as_ben} do
    shared = list_fixture(anna, name: "Supermarkt", shared: true)
    private = list_fixture(anna, name: "Apotheke", shared: false)
    entry_fixture(anna, shared, "Milch", "2 l")
    pills = entry_fixture(anna, private, "Ibuprofen")
    baumarkt = list_fixture(ben, name: "Baumarkt")

    assert ok(as_anna, "list_lists")["lists"] == [
             %{
               "id" => private.id,
               "name" => "Apotheke",
               "shared" => false,
               "mine" => true,
               "open_entries" => 1
             },
             %{
               "id" => shared.id,
               "name" => "Supermarkt",
               "shared" => true,
               "mine" => true,
               "open_entries" => 1
             }
           ]

    assert Enum.map(ok(as_ben, "list_lists")["lists"], &{&1["name"], &1["mine"]}) == [
             {"Baumarkt", true},
             {"Supermarkt", false}
           ]

    unknown = "Unknown list #{private.id}: call list_lists for the ids of the lists you see."
    assert refusal(as_ben, "read_list", %{"list_id" => private.id}) == unknown

    assert refusal(as_ben, "add_entries", %{
             "list_id" => private.id,
             "entries" => [%{"article" => "Pflaster"}]
           }) == unknown

    assert refusal(as_ben, "check_off", %{"entry_ids" => [pills.id]}) ==
             "Unknown entry #{pills.id}: call read_list for the ids of a list's entries."

    assert Shopping.list_open_entries(private) |> Enum.map(& &1.article.name) == ["Ibuprofen"]
    assert ok(as_anna, "list_lists")["lists"] |> Enum.all?(&(&1["id"] != baumarkt.id))
    assert Shopping.get_list(Scope.for_user(ben), private.id) == nil
  end

  test "reads a list in its area order and checks entries off and back",
       %{anna: anna, as_anna: as_anna, as_ben: as_ben} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    milk = entry_fixture(anna, list, "Milch", "2 l")
    apples = entry_fixture(anna, list, "Äpfel")
    bread = entry_fixture(anna, list, "Brot")

    assert %{"entries" => [%{"id" => id, "checked_off_at" => _at}]} =
             ok(as_ben, "check_off", %{"entry_ids" => [bread.id]})

    assert id == bread.id

    read = ok(as_anna, "read_list", %{"list_id" => list.id})

    assert {read["name"], read["shared"], read["mine"]} == {"Supermarkt", true, true}

    assert read["open_entries"] == [
             %{"id" => apples.id, "article" => "Äpfel", "area" => "Obst und Gemüse"},
             %{"id" => milk.id, "article" => "Milch", "detail" => "2 l", "area" => "Kühlregal"}
           ]

    assert [%{"id" => ^id, "article" => "Brot", "checked_off_at" => checked_off_at}] =
             read["recently_used"]

    assert {:ok, _at, 0} = DateTime.from_iso8601(checked_off_at)

    assert ok(as_anna, "put_back", %{"entry_ids" => [bread.id]}) == %{
             "entries" => [
               %{"id" => bread.id, "article" => "Brot", "area" => "Brot und Backwaren"}
             ]
           }

    assert length(Shopping.list_open_entries(list)) == 3
  end

  test "creates a list, lists the areas and sets an article's area by hand",
       %{anna: anna, ben: ben, as_ben: as_ben} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    entry_fixture(anna, list, "Spülmaschinentabs")
    Shopping.subscribe_lists()

    assert %{"id" => id, "name" => "Baumarkt", "shared" => false, "mine" => true} =
             ok(as_ben, "create_list", %{"name" => " Baumarkt "})

    assert Shopping.get_own_list(Scope.for_user(ben), id).name == "Baumarkt"

    areas = ok(as_ben, "list_areas")["areas"]
    assert hd(areas) == "Obst und Gemüse"
    assert "Haushalt" in areas

    assert ok(as_ben, "set_article_area", %{
             "article" => "spülmaschinentabs",
             "area" => "Haushalt"
           }) ==
             %{"article" => "Spülmaschinentabs", "area" => "Haushalt"}

    assert_receive {:list_changed, list_id} when list_id == list.id
    assert %{area_set_by_hand: true} = Catalog.get_article_by_name("Spülmaschinentabs")

    assert refusal(as_ben, "set_article_area", %{
             "article" => "Spülmaschinentabs",
             "area" => "Keller"
           }) =~
             ~s(Unknown area "Keller". Available: Obst und Gemüse, )

    assert refusal(as_ben, "set_article_area", %{"article" => "Einhorn", "area" => "Haushalt"}) ==
             ~s(Unknown article "Einhorn".)
  end

  test "refuses invalid entries before adding any", %{anna: anna, as_anna: as_anna} do
    list = list_fixture(anna)

    assert refusal(as_anna, "add_entries", %{
             "list_id" => list.id,
             "entries" => [%{"article" => "Milch"}, %{"article" => String.duplicate("x", 81)}]
           }) =~ "The app refused the article"

    assert refusal(as_anna, "add_entries", %{
             "list_id" => list.id,
             "entries" => [%{"article" => "Milch"}, %{"article" => "Brot", "area" => "Keller"}]
           }) =~ ~s(Unknown area "Keller")

    assert refusal(as_anna, "add_entries", %{
             "list_id" => list.id,
             "entries" => [%{"name" => "Milch"}]
           }) ==
             "Invalid arguments: entries[0].name: unknown argument"

    assert refusal(as_anna, "add_entries", %{"list_id" => list.id, "entries" => []}) ==
             "Invalid arguments: entries: missing"

    assert refusal(as_anna, "add_entries", %{
             "list_id" => list.id,
             "entries" => for(n <- 1..101, do: %{"article" => "Artikel #{n}"})
           }) == "At most 100 entries per call."

    assert refusal(as_anna, "create_list", %{"name" => "  "}) ==
             "Invalid arguments: name: missing"

    assert Shopping.list_open_entries(list) == []
  end

  test "a refusal while adding names the entry and keeps the ones before it",
       %{anna: anna, as_anna: as_anna} do
    list = list_fixture(anna)

    # Stands in for another writer taking the name between the checks and the insert.
    Repo.query!("""
    CREATE TRIGGER take_the_name BEFORE INSERT ON articles WHEN NEW.name = 'Glitzerkonfetti'
    BEGIN SELECT RAISE(ABORT, 'UNIQUE constraint failed: articles.folded_name'); END
    """)

    assert refusal(as_anna, "add_entries", %{
             "list_id" => list.id,
             "entries" => [%{"article" => "Milch"}, %{"article" => "Glitzerkonfetti"}]
           }) == ~s(Could not add "Glitzerkonfetti"; the entries before it were added.)

    assert [%{article: %{name: "Milch"}}] = Shopping.list_open_entries(list)
  end
end
