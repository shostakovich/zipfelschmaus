defmodule Zipfelschmaus.Users.User do
  @moduledoc false
  use Zipfelschmaus.Schema

  import Ecto.Changeset

  schema "users" do
    field :email, :string
    # The WebAuthn user handle: random, so passkeys reveal nothing about the account.
    field :passkey_handle, :binary, redact: true
    field :confirmed_at, :utc_datetime_usec
    field :authenticated_at, :utc_datetime_usec, virtual: true

    has_many :passkeys, Zipfelschmaus.Users.Passkey

    timestamps()
  end

  def create_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> update_change(:email, &String.trim/1)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+$/,
      message: "braucht ein @ und keine Leerzeichen"
    )
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, Zipfelschmaus.Repo)
    |> unique_constraint(:email)
    |> put_change(:passkey_handle, :crypto.strong_rand_bytes(16))
  end

  def confirm_changeset(user), do: change(user, confirmed_at: DateTime.utc_now())
end
