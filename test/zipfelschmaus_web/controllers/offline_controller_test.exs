defmodule ZipfelschmausWeb.OfflineControllerTest do
  use ZipfelschmausWeb.ConnCase

  setup %{conn: conn} do
    conn = get(conn, ~p"/offline")
    %{conn: conn, document: conn |> html_response(200) |> LazyHTML.from_document()}
  end

  describe "adding needs a connection" do
    test "the notice says that checking off still works and how many changes wait",
         %{document: document} do
      notice = LazyHTML.query(document, "#offline-notice")

      assert LazyHTML.text(notice) =~ "Keine Verbindung"
      assert LazyHTML.text(notice) =~ "Abhaken und Zurücklegen gehen weiter"
      assert notice |> LazyHTML.query("#offline-pending") |> Enum.count() == 1
    end

    test "the field for adding articles is not there", %{document: document} do
      assert document |> LazyHTML.query(~s(#add-entry, [name="entry[name]"])) |> Enum.count() == 0
    end
  end

  test "holds the start page, the list and the rows as Setzkasten markup", %{document: document} do
    for selector <- [
          "#offline-start #shared-lists ul.list",
          "#offline-start #private-lists ul.list",
          "#offline-list h1 [data-slot=name]",
          "#offline-list #open-entries",
          "#offline-list #recent-entries ul.list.setzkasten-list-dense",
          "template#offline-list-row",
          "template#offline-area",
          "template#offline-entry",
          "template#offline-recent-entry"
        ] do
      assert document |> LazyHTML.query(selector) |> Enum.count() == 1, selector
    end
  end

  test "lists the entries densely, those in Zuletzt verwendet quiet", %{document: document} do
    assert document |> template("offline-area") |> count("ul.list.setzkasten-list-dense") == 1
    assert document |> template("offline-entry") |> count("button.font-medium") == 1

    recent = template(document, "offline-recent-entry")
    assert count(recent, "li") == 1
    assert count(recent, "button.font-normal [data-slot=name]") == 1
    assert count(recent, "[data-slot=detail]") == 1
  end

  test "loads the offline script, not the LiveView one, and belongs to no one", %{
    conn: conn,
    document: document
  } do
    scripts = document |> LazyHTML.query("script[src]") |> LazyHTML.attribute("src")

    assert scripts == ["/assets/js/offline.js"]
    assert document |> LazyHTML.query("meta[name=csrf-token]") |> Enum.count() == 0
    assert get_resp_header(conn, "set-cookie") == []
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
  end

  defp template(document, id) do
    document
    |> LazyHTML.query("template#" <> id)
    |> LazyHTML.to_html()
    |> String.replace(~r{\A<template[^>]*>|</template>\z}, "")
    |> LazyHTML.from_fragment()
  end

  defp count(html, selector), do: html |> LazyHTML.query(selector) |> Enum.count()
end
