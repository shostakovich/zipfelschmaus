defmodule Zipfelschmaus.ShoppingFixtures do
  @moduledoc "Lists and their entries for tests."

  alias Zipfelschmaus.{Catalog, Shopping}
  alias Zipfelschmaus.Users.Scope

  def list_fixture(user, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Supermarkt", shared: false})
    {:ok, list} = Shopping.create_list(Scope.for_user(user), attrs)
    list
  end

  def entry_fixture(user, list, name, detail \\ nil) do
    {:ok, entry, _article_was} =
      Shopping.add_entry(Scope.for_user(user), list, %{name: name, detail: detail})

    entry
  end

  def area_id(name), do: Enum.find(Catalog.list_areas(), &(&1.name == name)).id
end
