defmodule ZipfelschmausWeb.Router do
  use ZipfelschmausWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZipfelschmausWeb.Layouts, :root}
    plug :protect_from_forgery
  end

  scope "/", ZipfelschmausWeb do
    get "/up", HealthController, :show
    get "/manifest.webmanifest", PwaController, :manifest
    get "/sw.js", PwaController, :service_worker
    get "/favicon.ico", PwaController, :favicon
  end

  scope "/", ZipfelschmausWeb do
    pipe_through :browser

    live_session :default do
      live "/", HomeLive
    end
  end
end
