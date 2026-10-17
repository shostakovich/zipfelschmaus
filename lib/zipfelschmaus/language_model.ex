defmodule Zipfelschmaus.LanguageModel do
  @moduledoc """
  A language model on the household's own server that answers with JSON by a schema
  (DECISIONS.md, 0007). Not available without its configuration; the app then works without it.
  """

  @callback available?() :: boolean

  @doc "The model's answer to `question`, as JSON text by `schema`."
  @callback answer(instructions :: String.t(), question :: String.t(), schema :: map) ::
              {:ok, String.t()} | {:error, term}

  @doc "The configured model."
  def impl, do: Application.fetch_env!(:zipfelschmaus, :language_model)
end
