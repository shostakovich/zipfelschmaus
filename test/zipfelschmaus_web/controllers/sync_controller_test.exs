defmodule ZipfelschmausWeb.SyncControllerTest do
  use ZipfelschmausWeb.ConnCase

  import Zipfelschmaus.ShoppingFixtures
  import Zipfelschmaus.UsersFixtures

  alias Zipfelschmaus.{Repo, Shopping}
  alias Zipfelschmaus.Shopping.Entry
  alias Zipfelschmaus.Users.Scope

  setup :register_and_log_in_user

  setup %{user: anna} do
    ben = user_fixture()
    %{anna: anna, as_ben: Scope.for_user(ben), list: list_fixture(anna, shared: true)}
  end

  describe "checking off without reception" do
    test "an offline check-off syncs later", %{conn: conn, anna: anna, as_ben: as_ben, list: list} do
      milk = entry_fixture(anna, list, "Milch", "2 l") |> created(minutes_ago(20))
      anna_checks_off_at = minutes_ago(18)
      {:ok, _milk} = Shopping.update_detail(as_ben, milk.id, %{detail: "3 l"})

      conn = post_changes(conn, [change(milk, true, anna_checks_off_at)])

      assert response(conn, 204)
      milk = Repo.get!(Entry, milk.id)
      assert milk.checked_off_at == anna_checks_off_at
      assert milk.check_changed_at == anna_checks_off_at
      assert milk.detail == "3 l"
    end

    test "a later change wins over an older offline check-off",
         %{conn: conn, anna: anna, as_ben: as_ben, list: list} do
      eggs = entry_fixture(anna, list, "Eier") |> created(minutes_ago(20))
      anna_checks_off_at = minutes_ago(18)
      {:ok, _eggs} = Shopping.check_off(as_ben, eggs.id)
      {:ok, _eggs} = Shopping.put_back(as_ben, eggs.id)

      conn = post_changes(conn, [change(eggs, true, anna_checks_off_at)])

      assert response(conn, 204)
      assert Entry.open?(Repo.get!(Entry, eggs.id))
    end
  end

  test "an applied change is announced on the list's topic",
       %{conn: conn, anna: anna, list: list} do
    milk = entry_fixture(anna, list, "Milch") |> created(minutes_ago(20))
    Shopping.subscribe_lists()

    post_changes(conn, [change(milk, true, minutes_ago(5))])

    assert_receive {:list_changed, id} when id == list.id
  end

  test "refuses changes that are not a list of entry, state and time", %{conn: conn} do
    for body <- [
          %{},
          %{changes: "all"},
          %{changes: [%{entry_id: 1, checked_off: "yes", at: "2026-10-17T10:02:00Z"}]},
          %{changes: [%{entry_id: 1, checked_off: true, at: "10:02"}]}
        ] do
      assert conn |> post_json(body) |> response(422)
    end
  end

  test "takes no changes without a signed-in user", %{anna: anna, list: list} do
    milk = entry_fixture(anna, list, "Milch")

    conn = post_changes(build_conn(), [change(milk, true, DateTime.utc_now())])

    assert redirected_to(conn) == ~p"/users/log-in"
    assert Entry.open?(Repo.get!(Entry, milk.id))
  end

  defp post_changes(conn, changes), do: post_json(conn, %{changes: changes})

  defp post_json(conn, body) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post(~p"/sync", JSON.encode!(body))
  end

  defp change(entry, checked_off, at),
    do: %{entry_id: entry.id, checked_off: checked_off, at: DateTime.to_iso8601(at)}

  defp minutes_ago(minutes), do: DateTime.add(DateTime.utc_now(), -minutes, :minute)

  defp created(entry, at),
    do: entry |> Ecto.Changeset.change(check_changed_at: at) |> Repo.update!()
end
