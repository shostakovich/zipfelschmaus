defmodule Mix.Tasks.Zipfelschmaus.CreateUser do
  @shortdoc "Creates a user: mix zipfelschmaus.create_user EMAIL"
  @moduledoc """
  Creates a user, who then signs in with a link sent by mail.

      mix zipfelschmaus.create_user anna@example.org

  In the container: `bin/zipfelschmaus eval 'Zipfelschmaus.Release.create_user("…")'`.
  """
  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run([email]) do
    case Zipfelschmaus.Users.create_user(%{email: email}) do
      {:ok, user} -> Mix.shell().info("Created #{user.email}.")
      {:error, changeset} -> Mix.raise("Could not create #{email}: #{inspect(changeset.errors)}")
    end
  end

  def run(_args), do: Mix.raise("usage: mix zipfelschmaus.create_user EMAIL")
end
