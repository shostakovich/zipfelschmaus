defmodule ZipfelschmausWeb.SharedListsTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.{FakeLanguageModel, Shopping}
  alias Zipfelschmaus.Shopping.AreaGuesses

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

    anna_view |> form("#add-entry", entry: %{name: "Milch"}) |> render_submit()

    assert has_element?(ben_view, "#open-entries li", "Milch")
  end

  test "a check-off in one session moves the entry to Zuletzt verwendet in the other",
       %{conn: conn, anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    entry = entry_fixture(anna, list, "Eier")
    {:ok, anna_view, _html} = live(conn, ~p"/lists/#{list}")
    {:ok, ben_view, _html} = live(ben_conn, ~p"/lists/#{list}")

    ben_view |> element("#entry-#{entry.id} button", "Abhaken: Eier") |> render_click()

    refute has_element?(anna_view, "#open-entries #entry-#{entry.id}")
    assert has_element?(anna_view, "#recent-entries #recent-entry-#{entry.id}", "Eier")
    assert has_element?(ben_view, "#flash-group", "Eier abgehakt")
    refute has_element?(anna_view, "#flash-group", "Eier abgehakt")
  end

  test "adding an article that is already on the list keeps one entry and its detail",
       %{conn: conn, anna: anna, ben_conn: ben_conn} do
    list = list_fixture(anna, name: "Supermarkt", shared: true)
    entry_fixture(anna, list, "Milch", "2 l")
    {:ok, anna_view, _html} = live(conn, ~p"/lists/#{list}")
    {:ok, ben_view, _html} = live(ben_conn, ~p"/lists/#{list}")

    ben_view |> form("#add-entry", entry: %{name: "Milch"}) |> render_submit()

    for view <- [anna_view, ben_view] do
      assert open_entry_titles(view) == ["Abhaken: Milch"]
      assert has_element?(view, "#open-entries li", "2 l")
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

  describe "the area of a new article" do
    setup do
      test = self()

      FakeLanguageModel.stub(fn "Spülmaschinentabs" ->
        send(test, {:guessing, self()})
        receive do: (:answer -> {:ok, ~s({"area": "Drogerie"})})
      end)
    end

    test "is guessed later and moves the entry for both",
         %{conn: conn, anna: anna, ben_conn: ben_conn} do
      list = list_fixture(anna, name: "Supermarkt", shared: true)
      {:ok, anna_view, _html} = live(conn, ~p"/lists/#{list}")
      {:ok, ben_view, _html} = live(ben_conn, ~p"/lists/#{list}")

      anna_view |> form("#add-entry", entry: %{name: "Spülmaschinentabs"}) |> render_submit()

      for view <- [anna_view, ben_view],
          do: assert(has_element?(view, "#area-sonstiges li", "Spülmaschinentabs"))

      answer_guess()

      for view <- [anna_view, ben_view] do
        assert has_element?(view, "#area-drogerie li", "Spülmaschinentabs")
        refute has_element?(view, "#area-sonstiges")
      end
    end

    test "is not guessed over an area set by hand before the answer",
         %{conn: conn, anna: anna} do
      list = list_fixture(anna, name: "Supermarkt", shared: true)
      drugstore = list_fixture(anna, name: "DM")
      {:ok, view, _html} = live(conn, ~p"/lists/#{list}")
      {:ok, drugstore_view, _html} = live(conn, ~p"/lists/#{drugstore}")
      view |> form("#add-entry", entry: %{name: "Spülmaschinentabs"}) |> render_submit()
      entry_fixture(anna, drugstore, "Spülmaschinentabs")
      [entry] = Shopping.list_open_entries(list)

      view |> element("#entry-#{entry.id}-area-menu-item") |> render_click()
      view |> form("#edit-area", edit: %{area_id: area_id("Haushalt")}) |> render_submit()
      answer_guess()

      for view <- [view, drugstore_view] do
        assert has_element?(view, "#area-haushalt li", "Spülmaschinentabs")
        refute has_element?(view, "#area-drogerie")
      end
    end

    defp answer_guess do
      assert_receive {:guessing, guesser}
      send(guesser, :answer)
      :sys.get_state(AreaGuesses)
    end
  end

  defp open_entry_titles(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#open-entries li .list-col-grow > button")
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.split() |> Enum.join(" ")))
  end
end
