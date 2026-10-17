defmodule ZipfelschmausWeb.OfflineController do
  @moduledoc """
  The page the service worker shows for every page it cannot load: `offline.js` fills it with
  the start page or a list from the offline copy, cloning the Setzkasten markup of its
  templates. It holds nothing of a user's, so it needs no sign-in.
  """
  use ZipfelschmausWeb, :controller

  alias ZipfelschmausWeb.Layouts

  def show(conn, _params) do
    conn
    |> put_resp_header("cache-control", "no-cache")
    |> render(:show, page_title: Layouts.page_title("Offline"))
  end
end
