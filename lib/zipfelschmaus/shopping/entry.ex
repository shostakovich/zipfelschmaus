defmodule Zipfelschmaus.Shopping.Entry do
  @moduledoc """
  An article on a list, at most once per list, with an optional detail. It is open until
  checked off; `check_changed_at` is when it was last checked off or put back.
  """
  use Zipfelschmaus.Schema

  import Ecto.Changeset

  alias Zipfelschmaus.Catalog.Article
  alias Zipfelschmaus.Shopping.ShoppingList

  schema "entries" do
    field :detail, :string
    field :checked_off_at, :utc_datetime_usec
    field :check_changed_at, :utc_datetime_usec

    belongs_to :list, ShoppingList
    belongs_to :article, Article

    timestamps()
  end

  def detail_changeset(entry, attrs), do: entry |> cast(attrs, [:detail]) |> validate_detail()

  def validate_detail(changeset) do
    changeset
    |> update_change(:detail, &(&1 && String.trim(&1)))
    |> validate_length(:detail, max: 80)
  end

  def open?(%__MODULE__{checked_off_at: checked_off_at}), do: is_nil(checked_off_at)
end
