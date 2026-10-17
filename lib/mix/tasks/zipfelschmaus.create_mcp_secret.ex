defmodule Mix.Tasks.Zipfelschmaus.CreateMcpSecret do
  @shortdoc "Gives a user a new MCP secret: mix zipfelschmaus.create_mcp_secret EMAIL"
  @moduledoc """
  Gives a user a new secret for the MCP endpoint and prints the endpoint's path; the old secret
  stops working.

      mix zipfelschmaus.create_mcp_secret anna@example.org

  In the container: `bin/zipfelschmaus eval 'Zipfelschmaus.Release.create_mcp_secret("…")'`.
  """
  use Mix.Task

  alias Zipfelschmaus.Users

  @requirements ["app.start"]

  @impl true
  def run([email]) do
    case Users.get_user_by_email(email) do
      nil ->
        Mix.raise("There is no user #{email}.")

      user ->
        Mix.shell().info("The MCP endpoint of #{email} is /mcp/#{Users.create_mcp_secret(user)}.")
    end
  end

  def run(_args), do: Mix.raise("usage: mix zipfelschmaus.create_mcp_secret EMAIL")
end
