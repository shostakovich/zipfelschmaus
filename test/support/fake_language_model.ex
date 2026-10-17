defmodule Zipfelschmaus.FakeLanguageModel do
  @moduledoc """
  The language model in tests: answers with the function given to `stub/1`, called in the
  process that asks with the question, or with it and the schema. Without a stub no model is configured. At the test's end
  the area guesses still queued run before the stub goes.
  """
  @behaviour Zipfelschmaus.LanguageModel

  def stub(fun) when is_function(fun, 1) or is_function(fun, 2) do
    Application.put_env(:zipfelschmaus, __MODULE__, fun)

    ExUnit.Callbacks.on_exit(fn ->
      :sys.get_state(Zipfelschmaus.Shopping.AreaGuesses)
      Application.delete_env(:zipfelschmaus, __MODULE__)
    end)
  end

  @impl true
  def available?, do: Application.get_env(:zipfelschmaus, __MODULE__) != nil

  @impl true
  def answer(_instructions, question, schema) do
    case Application.fetch_env!(:zipfelschmaus, __MODULE__) do
      fun when is_function(fun, 1) -> fun.(question)
      fun -> fun.(question, schema)
    end
  end
end
