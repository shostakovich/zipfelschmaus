defmodule Zipfelschmaus.ShoppingFixtures do
  @moduledoc "Lists and their entries for tests."

  alias Zipfelschmaus.Shopping
  alias Zipfelschmaus.Users.Scope

  def list_fixture(user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Supermarkt", shared: false})
    {:ok, list} = Shopping.create_list(Scope.for_user(user), attrs)
    list
  end

  def entry_fixture(user, list, name, detail \\ nil) do
    {:ok, entry} = Shopping.add_entry(Scope.for_user(user), list, %{name: name, detail: detail})
    entry
  end
end
