defmodule ZipfelschmausWeb.ListSettingsLiveTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Setzkasten.Test.Confirm
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.Shopping
  alias Zipfelschmaus.Users.Scope

  setup :register_and_log_in_user

  test "creates a list and opens it", %{conn: conn, user: user} do
    {:ok, view, html} = live(conn, ~p"/lists/new")
    assert html =~ "Neue Liste · ZipfelSchmaus"
    refute has_element?(view, "#delete-list")

    {:ok, _list_view, html} =
      view
      |> form("#list-form", list: %{name: " Apotheke ", shared: "false"})
      |> render_submit()
      |> follow_redirect(conn)

    assert [list] = Shopping.list_lists(Scope.for_user(user))
    assert %{name: "Apotheke", shared: false} = list
    assert html =~ "Apotheke · ZipfelSchmaus"
  end

  test "a list needs a name", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/lists/new")

    assert view |> form("#list-form", list: %{name: ""}) |> render_change() =~
             "Muss ausgefüllt werden"
  end

  test "renames and shares a list", %{conn: conn, user: user} do
    list = list_fixture(user, name: "DM", shared: false)
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}/settings")
    assert has_element?(view, ~s(#list_name[value="DM"]))

    view
    |> form("#list-form", list: %{name: "Drogerie", shared: "true"})
    |> render_submit()

    assert_redirect(view, ~p"/lists/#{list}")
    assert %{name: "Drogerie", shared: true} = Shopping.get_list(Scope.for_user(user), list.id)
  end

  test "deletes a list after asking", %{conn: conn, user: user} do
    list = list_fixture(user, name: "DM")
    {:ok, view, _html} = live(conn, ~p"/lists/#{list}/settings")

    confirm_click(view, "#delete-list", "Liste „DM“ löschen?")

    {path, flash} = assert_redirect(view)
    assert path == ~p"/"
    assert flash["info"] == "Liste „DM“ gelöscht."
    assert Shopping.get_list(Scope.for_user(user), list.id) == nil
  end

  test "the settings of a shared list are its owner's", %{user: user} do
    list = list_fixture(user, shared: true)
    other_conn = log_in_user(build_conn(), user_fixture())

    assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => message}}}} =
             live(other_conn, ~p"/lists/#{list}/settings")

    assert message == "Diese Liste gibt es für dich nicht."
  end
end
