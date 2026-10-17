defmodule Zipfelschmaus.Release do
  @moduledoc "Tasks run from the release, where Mix is not available."

  @app :zipfelschmaus

  # A second connection would race the first to switch an empty file to WAL.
  @repo_opts [pool_size: 1]

  def migrate do
    Application.ensure_loaded(@app)

    for repo <- Application.fetch_env!(@app, :ecto_repos) do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true), @repo_opts)
    end

    :ok
  end

  @doc "Creates a user who then signs in with a link sent by mail."
  def create_user(email) do
    Application.ensure_loaded(@app)

    {:ok, result, _apps} =
      Ecto.Migrator.with_repo(
        Zipfelschmaus.Repo,
        fn _repo -> Zipfelschmaus.Users.create_user(%{email: email}) end,
        @repo_opts
      )

    case result do
      {:ok, user} ->
        IO.puts("Created #{user.email}; the sign-in page sends them a link.")

      {:error, changeset} ->
        IO.puts(:stderr, "Could not create #{email}: #{inspect(changeset.errors)}")
        System.halt(1)
    end
  end

  @doc """
  Gives the user with `email` a new secret for the MCP endpoint and prints the endpoint's path;
  the old secret stops working.
  """
  def create_mcp_secret(email) do
    Application.ensure_loaded(@app)

    {:ok, secret, _apps} =
      Ecto.Migrator.with_repo(
        Zipfelschmaus.Repo,
        fn _repo ->
          user = Zipfelschmaus.Users.get_user_by_email(email)
          user && Zipfelschmaus.Users.create_mcp_secret(user)
        end,
        @repo_opts
      )

    if secret do
      IO.puts("The MCP endpoint of #{email} is /mcp/#{secret} on the app's address.")
    else
      IO.puts(:stderr, "There is no user #{email}.")
      System.halt(1)
    end
  end
end
