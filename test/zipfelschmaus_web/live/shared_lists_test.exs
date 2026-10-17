defmodule ZipfelschmausWeb.SharedListsTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  setup :register_and_log_in_user

  setup %{user: anna} do
    ben = user_fixture()
    %{anna: anna, ben: ben, ben_conn: log_in_user(build_conn(), ben)}
  end

  test "an entry added in one session appears in the other",
       %{conn: conn, anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    {:ok, anna_view, _html} = live(conn, ~p"/lists/#{list}")
    {:ok, ben_view, _html} = live(ben_conn, ~p"/lists/#{list}")

    anna_view |> form("#add-entry", entry: %{name: "Milch", detail: "2 l"}) |> render_submit()

    assert has_element?(ben_view, "#open-entries li", "Milch")
    assert has_element?(ben_view, "#open-entries li", "2 l")
  end

  test "a check-off in one session moves the entry to Zuletzt verwendet in the other",
       %{conn: conn, anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    entry = entry_fixture(anna, list, "Eier")
    {:ok, anna_view, _html} = live(conn, ~p"/lists/#{list}")
    {:ok, ben_view, _html} = live(ben_conn, ~p"/lists/#{list}")

    ben_view |> element("#entry-#{entry.id} button", "Abhaken: Eier") |> render_click()

    refute has_element?(anna_view, "#open-entries #entry-#{entry.id}")
    assert has_element?(anna_view, "#recent-entries #entry-#{entry.id}", "Eier")
  end

  test "adding an article that is already on the list updates its detail",
       %{conn: conn, anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    entry_fixture(anna, list, "Milch", "2 l")
    {:ok, anna_view, _html} = live(conn, ~p"/lists/#{list}")
    {:ok, ben_view, _html} = live(ben_conn, ~p"/lists/#{list}")

    ben_view
    |> form("#add-entry", entry: %{name: "Milch", detail: "1 l Hafer"})
    |> render_submit()

    for view <- [anna_view, ben_view] do
      assert open_entry_titles(view) == ["Abhaken: Milch"]
      assert has_element?(view, "#open-entries li", "1 l Hafer")
      refute has_element?(view, "#open-entries li", "2 l")
    end
  end

  test "a private list is neither shown to nor reachable by the other user",
       %{anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "Apotheke", shared: false)

    {:ok, _home, html} = live(ben_conn, ~p"/")
    refute html =~ "Apotheke"

    assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => message}}}} =
             live(ben_conn, ~p"/lists/#{list}")

    assert message == "Diese Liste gibt es für dich nicht."

    assert {:error, {:live_redirect, %{to: "/"}}} = live(ben_conn, ~p"/lists/#{list}/settings")
  end

  test "unsharing hides the list from the other user at once",
       %{conn: conn, anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "DM", shared: true)
    {:ok, ben_home, _html} = live(ben_conn, ~p"/")
    {:ok, ben_list, _html} = live(ben_conn, ~p"/lists/#{list}")
    assert has_element?(ben_home, "#list-#{list.id}", "DM")

    {:ok, settings, _html} = live(conn, ~p"/lists/#{list}/settings")
    settings |> form("#list-form", list: %{shared: "false"}) |> render_submit()

    refute has_element?(ben_home, "#list-#{list.id}")
    {path, flash} = assert_redirect(ben_list)
    assert path == ~p"/"
    assert flash["error"] == "Die Liste „DM“ gibt es für dich nicht mehr."
  end

  defp open_entry_titles(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#open-entries li .list-col-grow > button")
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))
  end
end
