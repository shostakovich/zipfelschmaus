defmodule Zipfelschmaus.NamesTest do
  use ExUnit.Case, async: true

  alias Zipfelschmaus.Names

  test "normalize/1 collapses and trims whitespace" do
    assert Names.normalize("  Rote \t Bete ") == "Rote Bete"
  end

  test "normalize/1 composes characters, so a decomposed name folds the same" do
    decomposed = String.normalize("Äpfel", :nfd)

    assert Names.normalize(decomposed) == "Äpfel"
    assert Names.fold(decomposed) == Names.fold("Äpfel")
  end

  test "fold/1 makes names the same regardless of case and spacing" do
    assert Names.fold(" ÄPFEL ") == Names.fold("äpfel")
    assert Names.fold("Straße") == Names.fold("STRASSE")
  end

  test "sort_key/1 sorts umlauts with their base letter" do
    assert Enum.sort_by(["Zucker", "Bananen", "Äpfel", "Öl"], &Names.sort_key/1) ==
             ["Äpfel", "Bananen", "Öl", "Zucker"]
  end
end
