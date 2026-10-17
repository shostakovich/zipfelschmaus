defmodule Zipfelschmaus.Shopping.AreaGuesses do
  @moduledoc """
  The queue of new articles whose area the language model guesses, see
  `Zipfelschmaus.Shopping.guess_area/1`: one after the other, so that the model on the home
  server never gets two requests at once. A guess queued at a stop is lost; the article then
  stays in "Sonstiges".
  """
  use GenServer

  require Logger

  alias Zipfelschmaus.Shopping

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Queues the article with `article_id`."
  def enqueue(article_id), do: GenServer.cast(__MODULE__, {:guess, article_id})

  @impl true
  def init(_opts), do: {:ok, nil}

  # A crash would lose the articles queued behind this one.
  @impl true
  def handle_cast({:guess, article_id}, state) do
    Shopping.guess_area(article_id)
    {:noreply, state}
  catch
    kind, reason ->
      Logger.error(
        "guessing the area of article #{article_id} failed: " <>
          Exception.format(kind, reason, __STACKTRACE__)
      )

      {:noreply, state}
  end
end
