defmodule ZipfelschmausWeb.HomeLiveTest do
  use ZipfelschmausWeb.ConnCase

  test "the start page shows the empty lists in the app's shell", %{conn: conn} do
    document = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("title") |> LazyHTML.text() =~ "Listen · ZipfelSchmaus"
    assert document |> LazyHTML.query("main h1") |> LazyHTML.text() =~ "Listen"
    assert document |> LazyHTML.query("#lists-empty") |> LazyHTML.text() =~ "Noch keine Listen"
  end
end
