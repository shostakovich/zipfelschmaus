defmodule ZipfelschmausWeb.HomeLiveTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.Shopping
  alias Zipfelschmaus.Users.Scope

  describe "signed in" do
    setup :register_and_log_in_user

    test "the start page without lists says so in the app's shell", %{conn: conn} do
      document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("title") |> LazyHTML.text() =~ "Listen · ZipfelSchmaus"
      assert document |> LazyHTML.query("main h1") |> LazyHTML.text() =~ "Listen"
      assert document |> LazyHTML.query("#lists-empty") |> LazyHTML.text() =~ "Noch keine Listen"

      assert document |> LazyHTML.query(~s(a.setzkasten-fab[href="/lists/new"])) |> Enum.count() ==
               1
    end

    test "groups the lists into shared and private ones, with their open entries",
         %{conn: conn, user: user} do
      other = user_fixture()
      supermarkt = list_fixture(user, name: "Supermarkt", shared: true)
      baumarkt = list_fixture(other, name: "Baumarkt", shared: true)
      apotheke = list_fixture(user, name: "Apotheke", shared: false)
      list_fixture(other, name: "Geheim", shared: false)
      entry_fixture(user, supermarkt, "Milch")
      entry_fixture(user, supermarkt, "Eier")

      {:ok, view, html} = live(conn, ~p"/")

      refute html =~ "Geheim"
      refute has_element?(view, "#lists-empty")

      assert has_element?(
               view,
               ~s(#shared-lists #list-#{baumarkt.id} a[href="/lists/#{baumarkt.id}"])
             )

      assert has_element?(view, "#shared-lists #list-#{supermarkt.id}", "2 offen")
      assert has_element?(view, "#private-lists #list-#{apotheke.id}", "Nichts offen")
    end

    test "shows lists that others create or change at once", %{conn: conn} do
      other = user_fixture()
      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, list} = Shopping.create_list(Scope.for_user(other), %{name: "DM", shared: true})
      assert has_element?(view, "#shared-lists #list-#{list.id}", "DM")

      entry_fixture(other, list, "Zahnpasta")
      assert has_element?(view, "#list-#{list.id}", "1 offen")
    end

    test "the dock and the sidebar lead to Listen and Ich", %{conn: conn} do
      document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

      for place <- ["nav.dock", "aside nav[aria-label=Hauptnavigation]"] do
        links = LazyHTML.query(document, "#{place} a")

        assert Enum.map(links, &LazyHTML.attribute(&1, "href")) == [["/"], ["/me"]]

        assert links |> Enum.map(&LazyHTML.text/1) |> Enum.map(&String.trim/1) == [
                 "Listen",
                 "Ich"
               ]

        assert document |> LazyHTML.query("#{place} a[aria-current=page]") |> Enum.count() == 1
      end
    end
  end

  test "sends anonymous visitors to the sign-in page", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == ~p"/users/log-in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Bitte melde dich an."
  end
end
