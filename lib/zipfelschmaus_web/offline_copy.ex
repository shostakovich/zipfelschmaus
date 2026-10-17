defmodule ZipfelschmausWeb.OfflineCopy do
  @moduledoc """
  The copy of every list the user sees that the `Offline` hook keeps in IndexedDB, so that
  without reception the lists still open and entries still check off: each list with its area
  order, its open entries and "Zuletzt verwendet". Pages that show lists push it as
  `offline_copy` whenever they load them.
  """

  import Phoenix.LiveView, only: [connected?: 1, push_event: 3]

  alias Zipfelschmaus.Shopping

  def push(socket) do
    if connected?(socket),
      do: push_event(socket, "offline_copy", %{lists: lists(socket.assigns.current_scope)}),
      else: socket
  end

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
