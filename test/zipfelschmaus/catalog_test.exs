defmodule Zipfelschmaus.CatalogTest do
  use Zipfelschmaus.DataCase

  alias Zipfelschmaus.Catalog
  alias Zipfelschmaus.Catalog.Article

  describe "the seeded catalog" do
    test "has the areas in their default order, Sonstiges last" do
      names = Enum.map(Catalog.list_areas(), & &1.name)

      assert Enum.take(names, 4) == [
               "Obst und Gemüse",
               "Brot und Backwaren",
               "Kühlregal",
               "Fleisch und Fisch"
             ]

      assert List.last(names) == "Sonstiges"
      assert "Drogerie" in names and "Haushalt" in names and "Tiefkühl" in names
    end

    test "has around 300 common articles, each in an area" do
      articles = Repo.preload(Catalog.list_articles(), :area)

      assert length(articles) in 280..360
      milk = Enum.find(articles, &(&1.name == "Milch"))
      assert milk.area.name == "Kühlregal"
      assert Enum.find(articles, &(&1.name == "Zahnpasta")).area.name == "Drogerie"
    end
  end

  describe "find_or_create_article/1" do
    test "finds an article regardless of case and spacing" do
      {:ok, article} = Catalog.find_or_create_article("  ÄPFEL ")

      assert article.name == "Äpfel"
    end

    test ~s(creates an unknown article in "Sonstiges") do
      {:ok, article} = Catalog.find_or_create_article(" Glitzer   Konfetti ")

      assert %Article{name: "Glitzer Konfetti", folded_name: "glitzer konfetti", picture: nil} =
               article

      assert Repo.preload(article, :area).area.name == "Sonstiges"
      assert {:ok, ^article} = Catalog.find_or_create_article("glitzer konfetti")
    end

    test "refuses a blank or overlong name" do
      assert {:error, changeset} = Catalog.find_or_create_article("   ")
      assert %{name: ["muss ausgefüllt werden"]} = errors_on(changeset)

      assert {:error, changeset} = Catalog.find_or_create_article(String.duplicate("a", 81))
      assert %{name: ["darf höchstens 80 Zeichen lang sein"]} = errors_on(changeset)
    end
  end
end
