defmodule ZipfelschmausWeb.HomeLiveTest do
  use ZipfelschmausWeb.ConnCase

  describe "signed in" do
    setup :register_and_log_in_user

    test "the start page shows the empty lists in the app's shell", %{conn: conn} do
      document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

      assert document |> LazyHTML.query("title") |> LazyHTML.text() =~ "Listen · ZipfelSchmaus"
      assert document |> LazyHTML.query("main h1") |> LazyHTML.text() =~ "Listen"
      assert document |> LazyHTML.query("#lists-empty") |> LazyHTML.text() =~ "Noch keine Listen"
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
