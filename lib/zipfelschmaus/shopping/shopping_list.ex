defmodule Zipfelschmaus.Shopping.ShoppingList do
  @moduledoc "A shopping list: its owner's alone, or shared with everyone in the household."
  use Zipfelschmaus.Schema

  import Ecto.Changeset

  alias Zipfelschmaus.Names
  alias Zipfelschmaus.Shopping.Entry
  alias Zipfelschmaus.Users.User

  schema "lists" do
    field :name, :string
    field :shared, :boolean, default: false
    field :open_count, :integer, virtual: true

    belongs_to :owner, User
    has_many :entries, Entry, foreign_key: :list_id

    timestamps()
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:name, :shared])
    |> update_change(:name, &(&1 && Names.normalize(&1)))
    |> validate_required([:name])
    |> validate_length(:name, max: 60)
  end
end
