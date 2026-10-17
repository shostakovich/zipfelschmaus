defmodule ZipfelschmausWeb.ConnCase do
  @moduledoc """
  Test case for tests that build a connection; database changes are rolled back via the sandbox.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint ZipfelschmausWeb.Endpoint

      use ZipfelschmausWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import ZipfelschmausWeb.ConnCase
    end
  end

  setup tags do
    Zipfelschmaus.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc "Setup helper: a signed-in user as `user` and their `conn`; see `log_in_user/3`."
  def register_and_log_in_user(%{conn: conn} = context) do
    user = Zipfelschmaus.UsersFixtures.user_fixture()
    opts = context |> Map.take([:token_authenticated_at]) |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user}
  end

  @doc "Signs `user` in on `conn`; `token_authenticated_at` backdates the sign-in."
  def log_in_user(conn, user, opts \\ []) do
    token = Zipfelschmaus.Users.generate_user_session_token(user)

    if authenticated_at = opts[:token_authenticated_at] do
      Zipfelschmaus.UsersFixtures.override_token_authenticated_at(token, authenticated_at)
    end

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
