defmodule ZipfelschmausWeb.OfflineCopy do
  @moduledoc """
  The copy of every list the user sees that the `Offline` hook keeps in IndexedDB, so that
  without reception the lists still open and entries still check off: each list with its area
  order, its open entries and "Zuletzt verwendet".
  """

  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1, push_event: 3]

  alias Zipfelschmaus.Shopping

  @doc """
  `on_mount` for signed-in pages: pushes the copy as `offline_copy` once connected and again
  after every list change. It subscribes the page to `"lists"`, so `{:list_changed, list_id}`
  also reaches the page's own `handle_info/2`.
  """
  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Shopping.subscribe_lists()
      {:cont, socket |> push() |> attach_hook(:offline_copy, :handle_info, &refresh/2)}
    else
      {:cont, socket}
    end
  end

  defp refresh({:list_changed, _list_id}, socket), do: {:cont, push(socket)}
  defp refresh(_message, socket), do: {:cont, socket}

  defp push(%{assigns: %{current_scope: scope}} = socket),
    do: push_event(socket, "offline_copy", %{user_id: scope.user.id, lists: lists(scope)})

  defp lists(scope) do
    for list <- Shopping.list_lists(scope) do
      %{
        id: list.id,
        name: list.name,
        shared: list.shared,
        areas: for(area <- Shopping.list_areas(list), do: %{id: area.id, name: area.name}),
        entries: Enum.map(entries(list), &entry/1)
      }
    end
  end

  defp entries(list), do: Shopping.list_open_entries(list) ++ Shopping.list_recent_entries(list)

  defp entry(entry) do
    %{
      id: entry.id,
      name: entry.article.name,
      detail: entry.detail,
      area_id: entry.article.area_id,
      checked_off_at: entry.checked_off_at,
      check_changed_at: entry.check_changed_at
    }
  end
end
