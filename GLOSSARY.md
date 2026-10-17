# ZipfelSchmaus

The language of a two-person household's shopping lists, recipes and pantry.

## Catalog

**Article** · _de:_ Artikel
- A thing you buy, cook with or store, once per household. Lists, recipes and the pantry point to it. Not an **Entry**, which is an article on one list.
- _Example:_ "Milch", "Kichererbsen (Dose)"
- _Avoid:_ Item, Product

**Area** · _de:_ Bereich
- The part of a shop an **Article** belongs to; the same for every list. Orders a list.
- _Example:_ "Obst und Gemüse", "Kühlregal", "Drogerie"
- _Avoid:_ Category, Section

**Staple** · _de:_ immer da
- An **Article** the household always has, so it is left out when a recipe's **Ingredients** go onto a list.
- _Example:_ Salz, Pfeffer, Öl

## Shopping

**List** · _de:_ Liste
- A shopping list, usually for one shop. It belongs to one user and is either private or shared with the other.
- _Example:_ "Supermarkt" (shared), "Apotheke" (private)

**Area order** · _de:_ Reihenfolge der Bereiche
- The order in which a **List** shows its **Areas**, the way you walk through that shop. Each list has its own.

**Entry** · _de:_ Eintrag
- An **Article** on a **List**, with an optional **Detail**. Open until checked off.
- _Avoid:_ Item, Position

**Detail** · _de:_ Angabe
- Free text on an **Entry**: an amount or a note.
- _Example:_ "2 l", "für Lasagne"
- _Avoid:_ Specification, Quantity

**Check off** · _de:_ abhaken
- Marking an **Entry** as bought; it moves to **Recently used**. Works offline and syncs later.

**Recently used** · _de:_ Zuletzt verwendet
- The checked-off **Entries** of a **List**, newest first; one tap puts one back on the list.

## Recipes

**Recipe** · _de:_ Rezept
- A dish with **Servings**, **Ingredients** and steps, shared by the household.

**Ingredient** · _de:_ Zutat
- One line of a **Recipe**: amount, unit, **Article** and note, plus the original text.
- _Example:_ "500 g schwarze Bohnen, getrocknet"

**Servings** · _de:_ Portionen
- How many people a **Recipe** feeds; changing it scales every **Ingredient**.

**Cooked** · _de:_ Gekocht
- Recording that a **Recipe** was made; counts towards "häufig gekocht".

## Pantry

**Batch** · _de:_ Posten
- Units of one **Article** with the same best-before date in the pantry, with a count.
- _Example:_ "3 Dosen Kichererbsen, MHD 11/2026"
- _Avoid:_ Stock, Item

**Best-before** · _de:_ MHD
- The date printed on the pack, kept as month and year, a day optional.

**Due** · _de:_ fällig
- A **Batch** whose **Best-before** is at most four weeks away. A due batch asks: used up, or still there with a new date.

**Take out** · _de:_ entnehmen
- Removing one unit by scanning its barcode; it comes off the **Batch** with the earliest **Best-before**.

**Target stock** · _de:_ Sollbestand
- How much of an **Article** the household wants to keep. Below it, the article shows under "Nachkaufen".
- _Example:_ "Wasser 40 l", "Kichererbsen 6"
