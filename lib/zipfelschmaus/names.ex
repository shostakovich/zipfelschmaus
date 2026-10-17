defmodule Zipfelschmaus.Names do
  @moduledoc "Names as stored, compared and sorted."

  @doc ~s(Composes to NFC, collapses whitespace and trims: `" Rote  Bete "` becomes `"Rote Bete"`.)
  def normalize(name), do: name |> String.normalize(:nfc) |> String.split() |> Enum.join(" ")

  @doc "The form in which two names are the same: normalized and case-folded."
  def fold(name), do: name |> normalize() |> :string.casefold()

  @doc ~s(A key that sorts names as a German reader expects: "Äpfel" before "Bananen".)
  def sort_key(name) do
    name
    |> fold()
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
  end
end
