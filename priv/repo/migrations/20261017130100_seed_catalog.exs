defmodule Zipfelschmaus.Repo.Migrations.SeedCatalog do
  use Ecto.Migration

  import Ecto.Query

  @areas [
    {"obst-und-gemuese", "Obst und Gemüse",
     ~w(Äpfel Bananen Birnen Orangen Mandarinen Zitronen Limetten Trauben Erdbeeren Himbeeren
        Heidelbeeren Kiwis Mangos Ananas Melone Wassermelone Pfirsiche Nektarinen Pflaumen Kirschen
        Avocados Tomaten Cherrytomaten Gurke Paprika Zucchini Aubergine Karotten Kartoffeln
        Süßkartoffeln Zwiebeln Frühlingszwiebeln Knoblauch Ingwer Brokkoli Blumenkohl Spinat
        Feldsalat Rucola Eisbergsalat Kopfsalat Champignons Lauch Sellerie Fenchel Kohlrabi Rotkohl
        Weißkohl Spargel Radieschen Kürbis Chilischoten Petersilie Schnittlauch Basilikum Koriander
        Minze Dill) ++ ["Rote Zwiebeln", "Rote Bete"]},
    {"brot-und-backwaren", "Brot und Backwaren",
     ~w(Brot Vollkornbrot Toastbrot Brötchen Brezeln Baguette Croissants Knäckebrot Laugenstangen
        Tortillas Fladenbrot Burgerbrötchen Kuchen Zwieback)},
    {"kuehlregal", "Kühlregal",
     ~w(Milch Hafermilch Sojamilch Butter Margarine Sahne Schmand Joghurt Naturjoghurt Quark Skyr
        Frischkäse Hüttenkäse Mozzarella Feta Gouda Emmentaler Parmesan Bergkäse Camembert Halloumi
        Reibekäse Mascarpone Ricotta Eier Buttermilch Kefir Pudding Tofu Räuchertofu Hummus Gnocchi
        Maultaschen Blätterteig Pizzateig Kräuterbutter) ++
       ["Saure Sahne", "Crème fraîche", "Griechischer Joghurt", "Frische Pasta", "Frische Hefe"]},
    {"fleisch-und-fisch", "Fleisch und Fisch",
     ~w(Hackfleisch Rinderhack Hähnchenbrust Hähnchenschenkel Putenbrust Schweinefilet Schnitzel
        Rindersteak Gulasch Bratwurst Salami Kochschinken Rohschinken Speck Speckwürfel Leberwurst
        Aufschnitt Chorizo Lachs Räucherlachs Garnelen Kabeljau Forelle) ++ ["Wiener Würstchen"]},
    {"fruehstueck", "Frühstück",
     ~w(Kaffee Kaffeebohnen Espresso Tee Kräutertee Kakao Müsli Haferflocken Cornflakes Granola
        Marmelade Honig Nussnougatcreme Erdnussbutter Ahornsirup) ++ ["Grüner Tee"]},
    {"nudeln-reis-und-konserven", "Nudeln, Reis und Konserven",
     ~w(Nudeln Spaghetti Penne Fusilli Lasagneplatten Spätzle Glasnudeln Reisnudeln Reis
        Basmatireis Risottoreis Couscous Bulgur Quinoa Linsen Kichererbsen Kidneybohnen Mais
        Tomatenmark Kokosmilch Thunfisch Sardinen Oliven Kapern Gewürzgurken Sauerkraut Gemüsebrühe
        Hühnerbrühe Pesto Tomatensauce Apfelmus) ++
       ["Rote Linsen", "Weiße Bohnen", "Schwarze Bohnen", "Gehackte Tomaten", "Passierte Tomaten"]},
    {"oel-gewuerze-und-backen", "Öl, Gewürze und Backen",
     ~w(Olivenöl Rapsöl Sonnenblumenöl Essig Balsamico Senf Ketchup Mayonnaise Sojasauce Salz
        Pfeffer Paprikapulver Curry Kreuzkümmel Zimt Oregano Muskat Chiliflocken Lorbeerblätter Sesam
        Mehl Zucker Puderzucker Vanillezucker Backpulver Natron Trockenhefe Speisestärke Gelatine
        Kuvertüre Mandeln Haselnüsse Walnüsse Rosinen) ++ ["Brauner Zucker", "Gemahlene Mandeln"]},
    {"suesses-und-knabbereien", "Süßes und Knabbereien",
     ~w(Schokolade Zartbitterschokolade Gummibärchen Kekse Butterkekse Chips Tortilla-Chips
        Salzstangen Erdnüsse Cashewkerne Studentenfutter Popcorn Müsliriegel Lakritz Bonbons
        Kaugummi Reiswaffeln)},
    {"getraenke", "Getränke",
     ~w(Wasser Mineralwasser Apfelsaft Orangensaft Multivitaminsaft Apfelschorle Cola Limonade
        Eistee Bier Weißwein Rotwein Sekt Sirup) ++
       ["Stilles Wasser", "Alkoholfreies Bier", "Tonic Water"]},
    {"tiefkuehl", "Tiefkühl",
     ~w(Tiefkühlpizza Pommes Fischstäbchen Erbsen Tiefkühlgemüse Rahmspinat Beerenmischung Eis
        Kroketten Eiswürfel Edamame Frühlingsrollen) ++ ["Tiefkühlkräuter"]},
    {"drogerie", "Drogerie",
     ~w(Zahnpasta Zahnbürste Zahnseide Mundspülung Duschgel Shampoo Spülung Seife Flüssigseife Deo
        Rasierer Rasierschaum Bodylotion Handcreme Sonnencreme Lippenpflege Wattepads Wattestäbchen
        Taschentücher Toilettenpapier Feuchttücher Pflaster Tampons Binden)},
    {"haushalt", "Haushalt",
     ~w(Spülmittel Klarspüler Spülmaschinensalz Waschmittel Weichspüler Allzweckreiniger
        Glasreiniger Badreiniger WC-Reiniger Entkalker Schwämme Spültücher Küchenrolle Müllbeutel
        Gefrierbeutel Frischhaltefolie Alufolie Backpapier Batterien Glühbirnen Kerzen Streichhölzer
        Servietten)},
    {"sonstiges", "Sonstiges", ~w(Blumen Katzenfutter Hundefutter Grillkohle Geschenkpapier)}
  ]

  def up do
    now = DateTime.to_iso8601(DateTime.utc_now())

    repo().insert_all(
      "areas",
      for {{key, name, _articles}, index} <- Enum.with_index(@areas, 1) do
        %{key: key, name: name, position: index * 10, inserted_at: now, updated_at: now}
      end
    )

    area_ids = repo().all(from(a in "areas", select: {a.key, a.id})) |> Map.new()

    repo().insert_all(
      "articles",
      for {key, _name, articles} <- @areas, name <- articles do
        %{
          name: name,
          folded_name: :string.casefold(name),
          area_id: Map.fetch!(area_ids, key),
          inserted_at: now,
          updated_at: now
        }
      end
    )
  end

  def down do
    repo().delete_all("articles")
    repo().delete_all("areas")
  end
end
