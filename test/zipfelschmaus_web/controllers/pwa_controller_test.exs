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
end
