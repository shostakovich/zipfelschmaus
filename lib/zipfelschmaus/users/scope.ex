defmodule Zipfelschmaus.Users.Scope do
  @moduledoc """
  The caller of a context function: which user is signed in. Lists are scoped by it, so a user
  sees only their own lists and those shared with them.
  """

  alias Zipfelschmaus.Users.User

  defstruct user: nil

  def for_user(%User{} = user), do: %__MODULE__{user: user}
  def for_user(nil), do: nil
end
