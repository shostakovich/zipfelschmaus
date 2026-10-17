defmodule Zipfelschmaus.Users.UserToken do
  @moduledoc """
  Session tokens, sign-in links and MCP secrets. A session token lives in the signed session and
  cookie and is stored as is, so a session can be ended on the server; a sign-in link's token and
  an MCP secret are stored only as their hash, so read access to the database signs no one in.
  """
  use Zipfelschmaus.Schema
  import Ecto.Query
  alias Zipfelschmaus.Users.UserToken

  @hash_algorithm :sha256
  @rand_size 32

  # Short, as whoever reads the mail can sign in with the link.
  @magic_link_validity_in_minutes 15
  @session_validity_in_days 14

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string
    field :authenticated_at, :utc_datetime_usec
    belongs_to :user, Zipfelschmaus.Users.User

    timestamps(updated_at: false)
  end

  @doc "How many days a session token is valid."
  def session_validity_in_days, do: @session_validity_in_days

  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    dt = user.authenticated_at || DateTime.utc_now()
    {token, %UserToken{token: token, context: "session", user_id: user.id, authenticated_at: dt}}
  end

  @doc "A query for `{user, token_inserted_at}` of a session token that has not expired."
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: {%{user | authenticated_at: token.authenticated_at}, token.inserted_at}

    {:ok, query}
  end

  @doc "The encoded token for the mail and the record holding its hash."
  def build_email_token(user, context) do
    token = :crypto.strong_rand_bytes(@rand_size)

    {Base.url_encode64(token, padding: false),
     %UserToken{
       token: :crypto.hash(@hash_algorithm, token),
       context: context,
       sent_to: user.email,
       user_id: user.id
     }}
  end

  @doc """
  A query for `{user, token}` of a sign-in link that has not expired and went to the user's
  current address.
  """
  def verify_magic_link_token_query(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from token in by_token_and_context_query(hashed_token, "login"),
            join: user in assoc(token, :user),
            where: token.inserted_at > ago(^@magic_link_validity_in_minutes, "minute"),
            where: token.sent_to == user.email,
            select: {user, token}

        {:ok, query}

      :error ->
        :error
    end
  end

  @doc "A new MCP secret and the record holding its hash; it does not expire."
  def build_mcp_secret(user) do
    secret = :crypto.strong_rand_bytes(@rand_size)

    {Base.url_encode64(secret, padding: false),
     %UserToken{token: :crypto.hash(@hash_algorithm, secret), context: "mcp", user_id: user.id}}
  end

  @doc "A query for the user of an MCP secret."
  def verify_mcp_secret_query(secret) do
    with {:ok, decoded_secret} <- Base.url_decode64(secret, padding: false) do
      hashed_secret = :crypto.hash(@hash_algorithm, decoded_secret)

      {:ok,
       from(token in by_token_and_context_query(hashed_secret, "mcp"),
         join: user in assoc(token, :user),
         select: user
       )}
    end
  end

  defp by_token_and_context_query(token, context) do
    from UserToken, where: [token: ^token, context: ^context]
  end
end
