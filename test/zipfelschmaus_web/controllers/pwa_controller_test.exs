defmodule ZipfelschmausWeb.PwaControllerTest do
  use ZipfelschmausWeb.ConnCase

  test "the manifest names the app and lists its icons", %{conn: conn} do
    conn = get(conn, ~p"/manifest.webmanifest")

    assert response_content_type(conn, :json) =~ "application/manifest+json"

    assert %{
             "name" => "ZipfelSchmaus",
             "short_name" => "Schmaus",
             "lang" => "de",
             "display" => "standalone",
             "theme_color" => "#ffffff",
             "icons" => icons
           } = JSON.decode!(response(conn, 200))

    assert Enum.map(icons, &{&1["src"], &1["purpose"]}) == [
             {"/images/icons/icon-192.webp", "any"},
             {"/images/icons/icon-512.webp", "any"},
             {"/images/icons/maskable-512.webp", "maskable"}
           ]
  end

  test "the service worker keeps the offline page and the files it loads", %{conn: conn} do
    conn = get(conn, ~p"/sw.js")

    assert response_content_type(conn, :javascript)
    assert get_resp_header(conn, "cache-control") == ["no-cache"]
    assert [shell, version, worker] = conn |> response(200) |> String.split("\n", parts: 3)
    assert "const SHELL = " <> paths = shell
    assert "const VERSION = " <> _hash = version

    assert JSON.decode!(paths) == [
             "/offline",
             "/assets/css/app.css",
             "/assets/js/offline.js",
             "/images/icons/icon-192.webp",
             "/setzkasten/fonts/Figtree-Variable.woff2"
           ]

    assert worker =~ ~s(const OFFLINE_PAGE = "/offline")
  end

  test "the service worker changes with the offline page's templates", %{conn: conn} do
    templates =
      Enum.map(
        [
          "controllers/offline_html/show.html.heex",
          "components/layouts.ex",
          "components/layouts/offline_root.html.heex"
        ],
        &File.read!(Path.join("lib/zipfelschmaus_web", &1))
      )

    hash = Base.encode16(:crypto.hash(:sha256, templates))

    assert conn |> get(~p"/sw.js") |> response(200) =~ ~s(\nconst VERSION = "#{hash}"\n)
  end
end
