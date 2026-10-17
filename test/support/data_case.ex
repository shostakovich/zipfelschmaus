defmodule Zipfelschmaus.DataCase do
  @moduledoc """
  Test case for tests against the database; changes are rolled back via the sandbox. Runs
  synchronously: SQLite allows one writer.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias Zipfelschmaus.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Zipfelschmaus.DataCase
    end
  end

  setup tags do
    Zipfelschmaus.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc "Sets up the sandbox based on the test tags."
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Zipfelschmaus.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  The changeset's errors as a map of messages.

      assert %{name: ["muss ausgefüllt werden"]} = errors_on(changeset)
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &ZipfelschmausWeb.CoreComponents.translate_error/1)
  end
end
