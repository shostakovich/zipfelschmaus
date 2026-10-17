defmodule ZipfelschmausWeb.MeLiveTest do
  use ZipfelschmausWeb.ConnCase

  import Phoenix.LiveViewTest
  import Setzkasten.Test.Confirm
  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.Users

  describe "after a recent sign-in" do
    setup :register_and_log_in_user

    test "shows the address, the theme and the way out", %{conn: conn, user: user} do
      {:ok, lv, html} = live(conn, ~p"/me")

      assert html =~ "Ich · ZipfelSchmaus"
      assert html =~ user.email
      assert has_element?(lv, "#theme-toggle")
      assert has_element?(lv, ~s(#log-out[href="/users/log-out"][data-method=delete]))
      assert has_element?(lv, "nav.dock a[aria-current=page]", "Ich")
    end

    test "keeps the offline copy of the lists up to date", %{conn: conn, user: user} do
      list = list_fixture(user, name: "Supermarkt", shared: true)
      {:ok, lv, _html} = live(conn, ~p"/me")
      user_id = user.id

      assert_push_event lv, "offline_copy", %{
        user_id: ^user_id,
        lists: [%{name: "Supermarkt", entries: []}]
      }

      entry_fixture(user_fixture(), list, "Milch")

      assert_push_event lv, "offline_copy", %{
        lists: [%{name: "Supermarkt", entries: [%{name: "Milch"}]}]
      }
    end

    test "lists the passkeys and offers to add one", %{conn: conn, user: user} do
      passkey = passkey_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/me")

      assert has_element?(lv, "#passkey-#{passkey.id}", "Testgerät")
      assert has_element?(lv, "#passkey-register[phx-hook=PasskeyRegister] input[name=name]")
      refute has_element?(lv, "#passkeys-reauth")
    end

    test "shows the empty state without passkeys", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/me")

      assert html =~ "Noch kein Passkey hinterlegt."
    end

    test "refreshes the list once the hook registered a passkey", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/me")
      passkey = passkey_fixture(user)

      assert render_hook(lv, "passkey_registered", %{}) =~ "Passkey hinzugefügt."
      assert has_element?(lv, "#passkey-#{passkey.id}")
    end

    test "shows passkey errors from the hook", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/me")

      assert render_hook(lv, "passkey_error", %{"message" => "Kaputt."}) =~ "Kaputt."
    end

    test "deletes a passkey after asking", %{conn: conn, user: user} do
      passkey = passkey_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/me")

      assert confirm_click(lv, "#passkey-#{passkey.id}-delete", "Passkey „Testgerät“ löschen?") =~
               "Passkey gelöscht."

      refute has_element?(lv, "#passkey-#{passkey.id}")
      assert Users.list_passkeys(user) == []
    end

    test "deletes no passkey of another user", %{conn: conn} do
      passkey = passkey_fixture(user_fixture())
      {:ok, lv, _html} = live(conn, ~p"/me")

      assert render_click(lv, "delete_passkey", %{"id" => to_string(passkey.id)}) =~
               "Den Passkey gibt es nicht mehr."
    end
  end

  describe "after an older sign-in" do
    @describetag token_authenticated_at: DateTime.add(DateTime.utc_now(), -21, :minute)
    setup :register_and_log_in_user

    test "asks to sign in again before passkeys change", %{conn: conn, user: user} do
      passkey = passkey_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/me")

      assert has_element?(lv, "#passkey-#{passkey.id}")
      refute has_element?(lv, "#passkey-#{passkey.id}-delete")
      refute has_element?(lv, "#passkey-register")
      assert has_element?(lv, ~s(#passkeys-reauth a[href="/users/log-in"]))

      assert render_click(lv, "delete_passkey", %{"id" => to_string(passkey.id)}) =~
               "Bitte melde dich für diese Änderung noch einmal an."

      assert [_passkey] = Users.list_passkeys(user)
    end
  end

  test "needs a signed-in user", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/me")
  end
end
