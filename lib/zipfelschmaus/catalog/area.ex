defmodule Zipfelschmaus.Catalog.Area do
  @moduledoc "A part of the shop; `position` gives the default area order. Seeded, not edited."
  use Zipfelschmaus.Schema

  schema "areas" do
    field :key, :string
    field :name, :string
    field :position, :integer

    timestamps()
  end
end
