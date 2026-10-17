defmodule ZipfelschmausWeb.Router do
  use ZipfelschmausWeb, :router

  import ZipfelschmausWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZipfelschmausWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :fetch_current_scope_for_user
  end

  # JSON for the passkey hooks; same session and CSRF protection as the pages.
  pipeline :browser_json do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :fetch_current_scope_for_user
  end

  scope "/", ZipfelschmausWeb do
    get "/up", HealthController, :show
    get "/manifest.webmanifest", PwaController, :manifest
    get "/sw.js", PwaController, :service_worker
    get "/favicon.ico", PwaController, :favicon
  end

  scope "/", ZipfelschmausWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{ZipfelschmausWeb.UserAuth, :require_authenticated}] do
      live "/", HomeLive
      live "/lists/new", ListSettingsLive, :new
      live "/lists/:id", ListLive
      live "/lists/:id/settings", ListSettingsLive, :edit
      live "/me", MeLive
    end
  end

  scope "/", ZipfelschmausWeb do
    pipe_through [:browser_json, :require_authenticated_user]

    post "/me/passkeys/options", PasskeyController, :registration_options
    post "/me/passkeys", PasskeyController, :create
  end

  scope "/", ZipfelschmausWeb do
    pipe_through :browser_json

    post "/users/passkeys/options", PasskeyController, :authentication_options
  end

  scope "/", ZipfelschmausWeb do
    pipe_through :browser

    live_session :current_user,
      on_mount: [{ZipfelschmausWeb.UserAuth, :mount_current_scope}] do
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  if Application.compile_env(:zipfelschmaus, :dev_routes) do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview,
        csp_nonce_assign_key: %{script: :csp_nonce, style: :csp_nonce}
    end
  end
end
