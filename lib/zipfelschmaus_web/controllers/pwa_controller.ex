defmodule ZipfelschmausWeb.PwaController do
  @moduledoc """
  What makes the app installable: the web app manifest, the service worker
  (`pwa_controller/sw.js`) and the favicon browsers ask for at the root.
  """
  use ZipfelschmausWeb, :controller

  alias ZipfelschmausWeb.Layouts

  @external_resource Path.join(__DIR__, "pwa_controller/sw.js")
  @service_worker File.read!(Path.join(__DIR__, "pwa_controller/sw.js"))

  # Setzkasten's light page colour (base-100), for the splash screen and the title bar.
  @page_color "#ffffff"

  def manifest(conn, _params) do
    manifest = %{
      name: Layouts.app_name(),
      short_name: "Schmaus",
      description: "Einkaufslisten, Rezepte und Vorräte",
      lang: "de",
      dir: "ltr",
      id: "/",
      start_url: "/",
      scope: "/",
      display: "standalone",
      background_color: @page_color,
      theme_color: @page_color,
      icons: [
        icon(~p"/images/icons/icon-192.webp", "192x192", "any"),
        icon(~p"/images/icons/icon-512.webp", "512x512", "any"),
        icon(~p"/images/icons/maskable-512.webp", "512x512", "maskable")
      ]
    }

    conn
    |> put_resp_content_type("application/manifest+json")
    |> put_resp_header("cache-control", "no-cache")
    |> send_resp(200, JSON.encode!(manifest))
  end

  defp icon(src, sizes, purpose),
    do: %{src: src, sizes: sizes, type: "image/webp", purpose: purpose}

  def service_worker(conn, _params) do
    conn
    |> put_resp_content_type("text/javascript")
    |> put_resp_header("cache-control", "no-cache")
    |> send_resp(200, @service_worker)
  end

  def favicon(conn, _params) do
    conn
    |> put_resp_content_type("image/png", nil)
    |> put_resp_header("cache-control", "public, max-age=86400")
    |> send_file(200, Application.app_dir(:zipfelschmaus, "priv/static/images/icons/favicon.png"))
  end
end
