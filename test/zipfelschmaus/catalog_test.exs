defmodule Zipfelschmaus.CatalogTest do
  use Zipfelschmaus.DataCase

  import ExUnit.CaptureLog

  alias Zipfelschmaus.{Catalog, FakeLanguageModel}
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
      {:ok, article, :found} = Catalog.find_or_create_article("  ÄPFEL ")

      assert article.name == "Äpfel"
    end

    test ~s(creates an unknown article in "Sonstiges") do
      {:ok, article, :created} = Catalog.find_or_create_article(" Glitzer   Konfetti ")

      assert %Article{
               name: "Glitzer Konfetti",
               folded_name: "glitzer konfetti",
               picture: nil,
               area_set_by_hand: false
             } = article

      assert Repo.preload(article, :area).area.name == "Sonstiges"
      assert {:ok, ^article, :found} = Catalog.find_or_create_article("glitzer konfetti")
    end

    test "refuses a blank or overlong name" do
      assert {:error, changeset} = Catalog.find_or_create_article("   ")
      assert %{name: ["muss ausgefüllt werden"]} = errors_on(changeset)

      assert {:error, changeset} = Catalog.find_or_create_article(String.duplicate("a", 81))
      assert %{name: ["darf höchstens 80 Zeichen lang sein"]} = errors_on(changeset)
    end
  end

  describe "set_area_by_hand/2" do
    test "moves the article and marks its area as set by hand" do
      article = Catalog.get_article_by_name("Zahnpasta")
      household = Enum.find(Catalog.list_areas(), &(&1.name == "Haushalt"))

      {:ok, article} = Catalog.set_area_by_hand(article, household)

      assert %Article{area_id: area_id, area_set_by_hand: true} = article
      assert area_id == household.id
      assert Catalog.get_article_by_name("Zahnpasta").area_set_by_hand
    end

    test "puts the article back in the area picked although a guess moved it meanwhile" do
      article = Catalog.get_article_by_name("Zahnpasta")
      picked = Enum.find(Catalog.list_areas(), &(&1.id == article.area_id))
      household = Enum.find(Catalog.list_areas(), &(&1.name == "Haushalt"))

      Repo.update_all(from(a in Article, where: a.id == ^article.id),
        set: [area_id: household.id]
      )

      {:ok, _article} = Catalog.set_area_by_hand(article, picked)

      assert Catalog.get_article_by_name("Zahnpasta").area_id == picked.id
    end
  end

  describe "guess_area/1" do
    setup do
      {:ok, article, :created} = Catalog.find_or_create_article("Spülmaschinentabs")
      %{article: article}
    end

    test "moves the article to the area the model picks from the existing ones",
         %{article: article} do
      test = self()

      FakeLanguageModel.stub(fn question, schema ->
        send(test, {:asked, question, schema})
        {:ok, ~s({"area": "Drogerie"})}
      end)

      assert {:ok, %Article{area: %{name: "Drogerie"}}} = Catalog.guess_area(article.id)

      assert_received {:asked, "Spülmaschinentabs", schema}
      assert schema.properties.area.enum == Enum.map(Catalog.list_areas(), & &1.name)
      assert %{area: %{name: "Drogerie"}, area_set_by_hand: false} = reload(article)
    end

    test "an area set by hand while the model thinks wins", %{article: article} do
      FakeLanguageModel.stub(fn _question ->
        {:ok, _article} = Catalog.set_area_by_hand(article, area("Haushalt"))
        {:ok, ~s({"area": "Drogerie"})}
      end)

      assert Catalog.guess_area(article.id) == :unchanged
      assert %{area: %{name: "Haushalt"}, area_set_by_hand: true} = reload(article)
    end

    test "does not ask about an area set by hand", %{article: article} do
      {:ok, _article} = Catalog.set_area_by_hand(article, area("Haushalt"))
      test = self()
      FakeLanguageModel.stub(fn _question -> send(test, :asked) end)

      assert Catalog.guess_area(article.id) == :unchanged
      refute_received :asked
    end

    test ~s(a failing model leaves the article in "Sonstiges"), %{article: article} do
      FakeLanguageModel.stub(fn _question -> {:error, :unreachable} end)

      assert capture_log(fn -> assert Catalog.guess_area(article.id) == :unchanged end) =~
               "the area model failed: :unreachable"

      assert reload(article).area.name == "Sonstiges"
    end

    test "ignores an answer off the schema", %{article: article} do
      for answer <- [~s({"area": "Baumarkt"}), ~s({"bereich": "Drogerie"}), "Drogerie"] do
        FakeLanguageModel.stub(fn _question -> {:ok, answer} end)

        assert capture_log(fn -> assert Catalog.guess_area(article.id) == :unchanged end) =~
                 "the area model answered off the schema"
      end

      assert reload(article).area.name == "Sonstiges"
    end

    test "leaves the article as it is without a model", %{article: article} do
      assert Catalog.guess_area(article.id) == :unchanged
      assert reload(article).area.name == "Sonstiges"
    end
  end

  defp area(name), do: Enum.find(Catalog.list_areas(), &(&1.name == name))

  defp reload(article), do: Article |> Repo.get!(article.id) |> Repo.preload(:area)
end
