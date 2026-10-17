defmodule ZipfelschmausWeb.UserLive.ConfirmationTest do
  use ZipfelschmausWeb.ConnCase

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.Users

  setup do
    user = unconfirmed_user_fixture()
    token = extract_user_token(&Users.deliver_login_instructions(user, &1))
    %{user: user, token: token}
  end

  test "signs in and confirms the user once", %{conn: conn, user: user, token: token} do
    {:ok, lv, html} = live(conn, ~p"/users/log-in/#{token}")
    assert html =~ user.email

    form = form(lv, "#login-form", %{"user" => %{"token" => token}})
    render_submit(form)
    conn = follow_trigger_action(form, conn)

    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Willkommen!"
    assert redirected_to(conn) == ~p"/"
    assert get_session(conn, :user_token)
    assert Zipfelschmaus.Repo.get!(Zipfelschmaus.Users.User, user.id).confirmed_at

    {:ok, _lv, html} =
      build_conn()
      |> live(~p"/users/log-in/#{token}")
      |> follow_redirect(build_conn(), ~p"/users/log-in")

    assert html =~ "Der Link ist ungültig oder abgelaufen."
  end

  test "rejects an unknown token", %{conn: conn} do
    {:ok, _lv, html} =
      conn |> live(~p"/users/log-in/invalid") |> follow_redirect(conn, ~p"/users/log-in")

    assert html =~ "Der Link ist ungültig oder abgelaufen."
  end

  test "keeps the token out of the request log", %{conn: conn, token: token} do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)

    log = capture_log([level: :info], fn -> get(conn, ~p"/users/log-in/#{token}") end)

    refute log =~ token
  end
end
