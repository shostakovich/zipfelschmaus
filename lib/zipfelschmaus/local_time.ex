defmodule Zipfelschmaus.LocalTime do
  @moduledoc "The host's local time (`TZ` in the container), without a time zone database."

  @doc "The local wall-clock time of a UTC moment."
  def from_utc(%DateTime{} = utc) do
    utc
    |> DateTime.to_naive()
    |> NaiveDateTime.to_erl()
    |> :calendar.universal_time_to_local_time()
    |> NaiveDateTime.from_erl!(utc.microsecond)
  end
end
