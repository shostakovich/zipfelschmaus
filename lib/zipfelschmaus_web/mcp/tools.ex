defmodule ZipfelschmausWeb.MCP.Tools do
  @moduledoc """
  The MCP tools as `tools/list` shows them, and running them as a user. Three read; the others
  add and check off entries, create lists and move articles, as in the app. Nothing is deleted.
  A result is JSON text; a refused call returns its message as an error.
  """

  require Logger

  alias ZipfelschmausWeb.MCP.{Arguments, ListTools, OrderedJSON, ToolError}

  @read_only %{
    readOnlyHint: true,
    destructiveHint: false,
    idempotentHint: true,
    openWorldHint: false
  }
  @write %{
    readOnlyHint: false,
    destructiveHint: false,
    idempotentHint: false,
    openWorldHint: false
  }

  @doc "The definitions of the tools, in their order; properties are keyword lists for `OrderedJSON`."
  def list do
    for tool <- tools() do
      %{
        name: tool.name,
        title: tool.title,
        description: tool.description,
        inputSchema: object_schema(tool.properties),
        annotations: if(tool[:write], do: @write, else: @read_only)
      }
    end
  end

  defp object_schema(properties) do
    schema = %{
      type: "object",
      properties: for({name, _type, schema, _opts} <- properties, do: {name, schema}),
      additionalProperties: false
    }

    schema = if schema.properties == [], do: %{schema | properties: %{}}, else: schema

    case for {name, _type, _schema, opts} <- properties, opts[:required], do: name do
      [] -> schema
      required -> Map.put(schema, :required, Enum.map(required, &Atom.to_string/1))
    end
  end

  @doc "The names of the tools."
  def names, do: Enum.map(tools(), & &1.name)

  @doc """
  Runs a tool on its arguments (decoded JSON, nil for none) as the user of `scope`:
  `{text, error?}`, or `:unknown`.
  """
  def call(name, arguments, scope) do
    case Enum.find(tools(), &(&1.name == name)) do
      nil -> :unknown
      tool -> run(tool, arguments, scope)
    end
  end

  defp run(tool, arguments, scope) do
    result = tool.run.(Arguments.decode!(arguments, specs(tool.properties)), scope)
    {OrderedJSON.encode!(result), false}
  rescue
    refusal in ToolError ->
      {refusal.message, true}

    error ->
      Logger.error(
        "MCP tool #{tool.name} failed: " <> Exception.format(:error, error, __STACKTRACE__)
      )

      {"Internal error while running the tool (details in the server log).", true}
  end

  defp specs(properties) do
    Enum.map(properties, fn
      {name, {:objects, nested}, _schema, opts} -> {name, {:objects, specs(nested)}, opts}
      {name, type, _schema, opts} -> {name, type, opts}
    end)
  end

  defp tools do
    list_id =
      {:list_id, :integer, integer("The id of the list, from list_lists."), [required: true]}

    entry_ids =
      {:entry_ids, :integers,
       %{
         type: "array",
         description: "The ids of the entries, from read_list.",
         items: %{type: "integer"},
         minItems: 1
       }, [required: true]}

    entry = [
      {:article, :string,
       text(~s[The article's name in German, e.g. "Milch" or "Kichererbsen (Dose)".]),
       [required: true]},
      {:detail, :string, text(~s[An amount or a note, e.g. "2 l" or "für Lasagne".]), []},
      {:area, :string,
       text(
         "Only used for a new article: its area, a name from list_areas. Use " <>
           "set_article_area to move an existing one."
       ), []}
    ]

    [
      %{
        name: "list_lists",
        title: "Lists",
        description:
          "The lists you see, by name: your own and those shared in the household, each with its " <>
            "id, whether it is shared, whether it is yours, and its number of open entries.",
        properties: [],
        run: &ListTools.list_lists/2
      },
      %{
        name: "read_list",
        title: "Read list",
        description:
          "A list's open entries in the order of its shop's areas, then by name, and its recently " <>
            ~s[used ("Zuletzt verwendet") entries, the newest 30 checked off, newest first. Each ] <>
            "entry has its id, article, detail and area.",
        properties: [list_id],
        run: &ListTools.read_list/2
      },
      %{
        name: "list_areas",
        title: "Areas",
        description:
          "The areas of a shop an article can belong to, in their default order. The same for every list.",
        properties: [],
        run: &ListTools.list_areas/2
      },
      %{
        name: "add_entries",
        title: "Add entries",
        description:
          "Puts articles on a list by name, as in the app. An article already on the list is not " <>
            "added twice: its entry is opened again and takes the new detail (without a detail it " <>
            "keeps the old one). A name not known yet becomes a new article (new_article: true); " <>
            "its area is the one given, or else the app guesses it within seconds. Invalid entries " <>
            "refuse the whole call before anything is added.",
        properties: [
          list_id,
          {:entries, {:objects, entry},
           %{
             type: "array",
             description: "The articles to put on the list.",
             items: object_schema(entry),
             minItems: 1,
             maxItems: ListTools.max_entries()
           }, [required: true]}
        ],
        write: true,
        run: &ListTools.add_entries/2
      },
      %{
        name: "check_off",
        title: "Check off entries",
        description:
          ~s[Checks off entries, e.g. as bought: they move to recently used ("Zuletzt verwendet").],
        properties: [entry_ids],
        write: true,
        run: &ListTools.check_off/2
      },
      %{
        name: "put_back",
        title: "Put back entries",
        description: "Puts checked-off entries back on their list, as open entries.",
        properties: [entry_ids],
        write: true,
        run: &ListTools.put_back/2
      },
      %{
        name: "create_list",
        title: "Create list",
        description:
          "Creates a list of yours with the default area order, private unless shared is true.",
        properties: [
          {:name, :string, text(~s[The list's name, usually its shop, e.g. "Supermarkt".]),
           [required: true]},
          {:shared, :boolean,
           %{type: "boolean", description: "Share it with the household. Default false."}, []}
        ],
        write: true,
        run: &ListTools.create_list/2
      },
      %{
        name: "set_article_area",
        title: "Set an article's area",
        description:
          "Moves an article to another area, on every list. An area set this way counts as set by " <>
            "hand: the app's guess never overrides it.",
        properties: [
          {:article, :string, text("The article's name."), [required: true]},
          {:area, :string, text("The area's name, from list_areas."), [required: true]}
        ],
        write: true,
        run: &ListTools.set_article_area/2
      }
    ]
  end

  defp text(description), do: %{type: "string", description: description}

  defp integer(description), do: %{type: "integer", description: description}
end
