defmodule ZipfelschmausWeb.ListLiveTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.Shopping
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

  test "a tap checks an entry off and one in Zuletzt verwendet puts it back",
       %{conn: conn, user: user, list: list} do
    milk = entry_fixture(user, list, "Milch", "2 l")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> element("#entry-#{milk.id} button", "Abhaken: Milch") |> render_click()

    assert has_element?(view, "#entries-empty", "Nichts offen")
    assert has_element?(view, "#recent-entries #entry-#{milk.id}", "2 l")

    view |> element("#entry-#{milk.id} button", "Wieder auf die Liste: Milch") |> render_click()

    assert has_element?(view, "#open-entries #entry-#{milk.id}")
    refute has_element?(view, "#recent-entries")
  end

  test "adds a known article with a detail and empties the field",
       %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: "milch", detail: "2 l"}) |> render_change()
    view |> form("#add-entry", entry: %{name: "milch", detail: "2 l"}) |> render_submit()

    assert has_element?(view, "#area-kuehlregal li", "Milch")
    assert has_element?(view, "#area-kuehlregal li", "2 l")
    assert has_element?(view, ~s(#add-entry input[name="entry[name]"]:not([value]\)))
    assert has_element?(view, ~s(#add-entry input[name="entry[detail]"]:not([value]\)))
  end

  test ~s(an unknown name becomes a new article under "Sonstiges"), %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: "Glitzerkonfetti"}) |> render_submit()

    assert has_element?(view, "#area-sonstiges li", "Glitzerkonfetti")
  end

  test "an empty name is refused", %{conn: conn, list: list} do
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}")

    view |> form("#add-entry", entry: %{name: " ", detail: "2 l"}) |> render_submit()

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

  defp texts(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))
  end
end
