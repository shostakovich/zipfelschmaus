defmodule Zipfelschmaus.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Zipfelschmaus.Repo,
      {Phoenix.PubSub, name: Zipfelschmaus.PubSub},
      Zipfelschmaus.Shopping.AreaGuesses,
      ZipfelschmausWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Zipfelschmaus.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ZipfelschmausWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
