defmodule ZipfelschmausWeb.SyncController do
  @moduledoc """
  Takes the check-offs and put-backs queued offline, as `changes` of `entry_id`, `checked_off`
  and `at` (ISO 8601, the time on the device), and hands them to `Shopping.sync_check_states/2`.
  """
  use ZipfelschmausWeb, :controller

  alias Zipfelschmaus.Shopping

  @max_changes 1000

  def create(conn, %{"changes" => changes}) when is_list(changes) do
    with true <- length(changes) <= @max_changes,
         {:ok, changes} <- parse(changes) do
      Shopping.sync_check_states(conn.assigns.current_scope, changes)
      send_resp(conn, 204, "")
    else
      _invalid -> send_resp(conn, 422, "")
    end
  end

  def create(conn, _params), do: send_resp(conn, 422, "")

  defp parse(changes) do
    parsed = Enum.map(changes, &parse_change/1)

    if Enum.all?(parsed, &match?({:ok, _change}, &1)),
      do: {:ok, Enum.map(parsed, fn {:ok, change} -> change end)},
      else: :error
  end

  defp parse_change(%{"entry_id" => entry_id, "checked_off" => checked_off?, "at" => at})
       when is_integer(entry_id) and is_boolean(checked_off?) and is_binary(at) do
    with {:ok, at} <- Ecto.Type.cast(:utc_datetime_usec, at),
         do: {:ok, %{entry_id: entry_id, checked_off?: checked_off?, at: at}}
  end

  defp parse_change(_change), do: :error
end
