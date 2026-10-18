defmodule ZipfelschmausWeb.ListLiveTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.{Catalog, Shopping}
  alias Zipfelschmaus.Users.Scope

  setup :register_and_log_in_user

  setup %{user: user}, do: %{list: list_fixture(user, name: "Supermarkt", shared: true)}

  test "shows the open entries by area in the default order", %{
    conn: conn,
    user: user,
    list: list
  } do
    entry_fixture(user, list, "Zahnpasta")
    entry_fixture(user, list, "Milch", "2 l")
    entry_fixture(user, list, "Äpfel")

    {:ok, view, html} = live(conn, ~p"/lists/#{list}")

    assert html =~ "Supermarkt · ZipfelSchmaus"
    assert has_element?(view, "main h1", "Supermarkt")
    assert has_element?(view, "header", "3 offen")

    assert texts(view, "#open-entries section h2") == [
             "Obst und Gemüse 1",
             "Kühlregal 1",
             "Drogerie 1"
           ]

    assert has_element?(view, "#area-kuehlregal li", "2 l")
    assert has_element?(view, "#area-kuehlregal li .avatar", "K")
    refute has_element?(view, "#recent-entries")
  end

  test "groups the open entries in the list's own area order",
       %{conn: conn, user: user, list: list} do
    entry_fixture(user, list, "Zahnpasta")
    entry_fixture(user, list, "Milch")
    entry_fixture(user, list, "Äpfel")
    {:ok, list} = Shopping.move_area(Scope.for_user(user), list, area_id("Kühlregal"), :up)
    {:ok, _list} = Shopping.move_area(Scope.for_user(user), list, area_id("Kühlregal"), :up)

    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    assert texts(view, "#open-entries section h2") ==
             ["Kühlregal 1", "Obst und Gemüse 1", "Drogerie 1"]
  end

  test "the entry menu changes the detail", %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch", "2 l")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> element("#entry-#{milk.id}-detail-menu-item") |> render_click()

    assert has_element?(view, ~s(#edit-entry[data-show="true"]))
    assert has_element?(view, "#edit-entry-title", "Angabe für Milch")
    assert has_element?(view, ~s(#edit_detail[value="2 l"]))

    view |> form("#edit-detail", edit: %{detail: " 3 l "}) |> render_submit()

    assert has_element?(view, ~s(#edit-entry[data-show="false"]))
    refute has_element?(view, "#edit-detail")
    assert has_element?(view, "#area-kuehlregal #entry-#{milk.id}", "3 l")
  end

  test "an overlong detail is refused", %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch", "2 l")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")
    view |> element("#entry-#{milk.id}-detail-menu-item") |> render_click()

    view |> form("#edit-detail", edit: %{detail: String.duplicate("x", 81)}) |> render_submit()

    assert has_element?(view, "#edit_detail-error-0", "Darf höchstens 80 Zeichen lang sein")
    assert has_element?(view, "#entry-#{milk.id}", "2 l")
  end

  test "an area set in the entry menu applies on every list and stays",
       %{conn: conn, user: user, list: list} do
    tabs = entry_fixture(user, list, "Spülmaschinentabs")
    other = list_fixture(user, name: "DM")
    entry_fixture(user, other, "Spülmaschinentabs")
    {:ok, other_view, _html} = live(conn, ~p"/lists/#{other}")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")
    assert has_element?(view, "#area-sonstiges #entry-#{tabs.id}")

    view |> element("#entry-#{tabs.id}-area-menu-item") |> render_click()

    assert has_element?(view, "#edit-entry-title", "Bereich für Spülmaschinentabs")
    assert has_element?(view, ~s(#edit-area input[value="#{area_id("Sonstiges")}"][checked]))

    view
    |> form("#edit-area", edit: %{area_id: area_id("Haushalt")})
    |> render_submit()

    assert has_element?(view, "#area-haushalt #entry-#{tabs.id}")
    refute has_element?(view, "#area-sonstiges")
    assert has_element?(other_view, "#area-haushalt li", "Spülmaschinentabs")
    assert Catalog.get_article_by_name("Spülmaschinentabs").area_set_by_hand
  end

  test "closing the edit dialog changes nothing", %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch", "2 l")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")
    view |> element("#entry-#{milk.id}-detail-menu-item") |> render_click()

    render_hook(view, "close_edit", %{})

    assert has_element?(view, ~s(#edit-entry[data-show="false"]))
    assert has_element?(view, "#entry-#{milk.id}", "2 l")
  end

  test "a tap checks an entry off and one in Zuletzt verwendet puts it back",
       %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch", "2 l")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> element("#entry-#{milk.id} button", "Abhaken: Milch") |> render_click()

    assert has_element?(view, "#entries-empty", "Nichts offen")
    assert has_element?(view, "#recent-entries #recent-entry-#{milk.id}", "2 l")

    view
    |> element("#recent-entry-#{milk.id} button", "Wieder auf die Liste: Milch")
    |> render_click()

    assert has_element?(view, "#open-entries #entry-#{milk.id}")
    refute has_element?(view, "#recent-entries")
  end

  test "open rows strike out as they leave, rows in Zuletzt verwendet are quiet",
       %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch")
    eggs = entry_fixture(user, list, "Eier")
    {:ok, _eggs} = Shopping.check_off(Scope.for_user(user), eggs.id)

    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    assert has_element?(view, "#area-kuehlregal ul.setzkasten-list-dense #entry-#{milk.id}")
    assert has_element?(view, "#entry-#{milk.id}[phx-remove] .setzkasten-strike", "Milch")
    assert has_element?(view, "#recent-entries ul.setzkasten-list-dense #recent-entry-#{eggs.id}")
    assert has_element?(view, "#recent-entry-#{eggs.id} button.font-normal", "Eier")
    refute has_element?(view, "#recent-entry-#{eggs.id}[phx-remove]")
  end

  test "a check-off says so in a toast whose Rückgängig puts the entry back",
       %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch", "2 l")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> element("#entry-#{milk.id} button", "Abhaken: Milch") |> render_click()

    assert has_element?(view, "#flash-group [role=status]", "Milch abgehakt")

    view |> element("#flash-group button", "Rückgängig") |> render_click()

    assert has_element?(view, "#open-entries #entry-#{milk.id}", "2 l")
    refute has_element?(view, "#recent-entries")
    refute has_element?(view, "#flash-group", "Milch abgehakt")
  end

  test "adds a known article and empties the field", %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: "milch"}) |> render_change()
    view |> form("#add-entry", entry: %{name: "milch"}) |> render_submit()

    assert has_element?(view, "#area-kuehlregal li", "Milch")
    assert has_element?(view, ~s(#add-entry input[name="entry[name]"]:not([value]\)))
  end

  test "the field for adding sits in the composer bar", %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    assert has_element?(view, ~s(#add-entry-bar #add-entry input[name="entry[name]"]))
    assert has_element?(view, ~s(#add-entry-bar #add-entry button[type=submit]))
    refute has_element?(view, ~s(#add-entry input[name="entry[detail]"]))
  end

  test "an added article says so in a toast whose Angabe opens its detail",
       %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: "milch"}) |> render_submit()

    assert has_element?(view, "#flash-group [role=status]", "Milch hinzugefügt")

    view |> element("#flash-group button", "Angabe") |> render_click()

    assert has_element?(view, ~s(#edit-entry[data-show="true"]))
    assert has_element?(view, "#edit-entry-title", "Angabe für Milch")
    refute has_element?(view, "#flash-group", "Milch hinzugefügt")
  end

  test ~s(an unknown name becomes a new article under "Sonstiges"), %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: "Glitzerkonfetti"}) |> render_submit()

    assert has_element?(view, "#area-sonstiges li", "Glitzerkonfetti")
  end

  test "an empty name is refused", %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: " "}) |> render_submit()

    assert has_element?(view, "#entry_name-error-0", "Muss ausgefüllt werden")
    assert has_element?(view, "#entries-empty")
  end

  test "suggests Zuletzt verwendet first, then the other articles",
       %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch")
    Shopping.check_off(Scope.for_user(user), milk.id)

    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    assert texts(view, "#entry_name-listbox .setzkasten-option-group") ==
             ["Zuletzt verwendet", "Artikel"]

    assert texts(view, "[aria-labelledby=entry_name-group-0] [role=option]") == ["Milch"]
    articles = texts(view, "[aria-labelledby=entry_name-group-1] [role=option]")
    assert "Zahnpasta" in articles
    refute "Milch" in articles
  end

  test "the owner gets to the settings, others do not", %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")
    assert has_element?(view, ~s(#list-settings[href="/lists/#{list.id}/settings"]))

    other_conn = log_in_user(build_conn(), user_fixture())
    {:ok, view, _html} = live(other_conn, ~p"/lists/#{list}")
    refute has_element?(view, "#list-settings")
  end

  test "a deleted list sends its readers back to the start page",
       %{conn: conn, user: user, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    Shopping.delete_list(Scope.for_user(user), list)

    assert_redirect(view, ~p"/")
  end

  test "keeps the offline copy of every list the user sees", %{
    conn: conn,
    user: user,
    list: list
  } do
    milk = entry_fixture(user, list, "Milch", "2 l")
    eggs = entry_fixture(user, list, "Eier")
    {:ok, _eggs} = Shopping.check_off(Scope.for_user(user), eggs.id)
    list_fixture(user, name: "Apotheke", shared: false)
    list_fixture(user_fixture(), name: "Geheim", shared: false)

    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    assert_push_event view, "offline_copy", %{lists: [apotheke, supermarkt]}
    assert %{name: "Apotheke", shared: false, entries: []} = apotheke
    assert %{id: list_id, name: "Supermarkt", shared: true, areas: areas} = supermarkt
    assert list_id == list.id
    assert areas == Enum.map(Shopping.list_areas(list), &%{id: &1.id, name: &1.name})

    assert [
             %{
               id: milk_id,
               name: "Milch",
               detail: "2 l",
               area_id: milk_area_id,
               checked_off_at: nil,
               check_changed_at: %DateTime{}
             },
             %{name: "Eier", detail: nil, checked_off_at: %DateTime{}}
           ] = supermarkt.entries

    assert milk_id == milk.id
    assert milk_area_id == area_id("Kühlregal")

    view |> element("#entry-#{milk.id} button", "Abhaken: Milch") |> render_click()

    assert_push_event view, "offline_copy", %{lists: [_apotheke, %{entries: [first | _]}]}
    assert %{name: "Milch", checked_off_at: %DateTime{}} = first
  end

  test "keeps the offline copy of the other lists up to date", %{
    conn: conn,
    user: user,
    list: list
  } do
    apotheke = list_fixture(user, name: "Apotheke", shared: false)
    {:ok, view, _html} = live(conn, ~p"/lists/#{apotheke}")
    assert_push_event view, "offline_copy", %{lists: [_apotheke, %{entries: []}]}

    entry_fixture(user_fixture(), list, "Milch")

    assert_push_event view, "offline_copy", %{
      lists: [%{entries: []}, %{name: "Supermarkt", entries: [%{name: "Milch"}]}]
    }
  end

  defp texts(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))
  end
end
