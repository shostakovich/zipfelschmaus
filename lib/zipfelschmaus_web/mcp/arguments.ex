defmodule ZipfelschmausWeb.MCP.Arguments do
  @moduledoc """
  Strict decoding of tool arguments: an object with only the known properties, each of its type.
  A null, a blank text or an empty list counts as not given. Errors name the property, as in
  `entries[2].article`.

  Types: `:string`, `:integer`, `:boolean`, `:integers` (a list of integers) and
  `{:objects, properties}` (a list of objects, each decoded by `properties`). A property
  `{name, type, required: true}` must be given.
  """

  alias ZipfelschmausWeb.MCP.ToolError

  @defaults %{boolean: false, integers: []}

  @doc "The arguments by property name (atoms); raises a `ZipfelschmausWeb.MCP.ToolError`."
  def decode!(arguments, properties), do: object!(arguments, properties, nil)

  defp object!(nil, properties, path), do: object!(%{}, properties, path)

  defp object!(%{} = arguments, properties, path) do
    names = Map.new(properties, fn {name, _type, _opts} -> {Atom.to_string(name), name} end)

    case Enum.find(Map.keys(arguments), &(not Map.has_key?(names, &1))) do
      nil -> :ok
      unknown -> invalid!(join(path, unknown), "unknown argument")
    end

    Map.new(properties, fn {name, type, opts} ->
      key = Atom.to_string(name)
      path = join(path, key)

      case {given(Map.get(arguments, key)), opts[:required]} do
        {nil, true} -> invalid!(path, "missing")
        {nil, _optional} -> {name, default(type)}
        {value, _required} -> {name, value!(path, value, type)}
      end
    end)
  end

  defp object!(_arguments, _properties, nil),
    do: ToolError.raise!("Invalid arguments: expected an object")

  defp object!(_arguments, _properties, path), do: invalid!(path, "expected an object")

  defp join(nil, key), do: key
  defp join(path, key), do: path <> "." <> key

  defp given(value) when is_binary(value), do: if(String.trim(value) != "", do: value)
  defp given([]), do: nil
  defp given(value), do: value

  defp value!(path, value, type) do
    case value(path, value, type) do
      {:ok, value} -> value
      :error -> invalid!(path, "expected #{expected(type)}")
    end
  end

  defp invalid!(path, problem), do: ToolError.raise!("Invalid arguments: #{path}: #{problem}")

  defp default(type) when is_atom(type), do: Map.get(@defaults, type)
  defp default({:objects, _properties}), do: []

  defp value(_path, value, :string) when is_binary(value), do: {:ok, value}
  defp value(_path, value, :integer) when is_integer(value), do: {:ok, value}
  defp value(_path, value, :boolean) when is_boolean(value), do: {:ok, value}

  defp value(_path, values, :integers) when is_list(values),
    do: if(Enum.all?(values, &is_integer/1), do: {:ok, values}, else: :error)

  defp value(path, values, {:objects, properties}) when is_list(values) do
    {:ok,
     values
     |> Enum.with_index()
     |> Enum.map(fn {value, index} -> object!(value, properties, "#{path}[#{index}]") end)}
  end

  defp value(_path, _value, _type), do: :error

  defp expected(:string), do: "a string"
  defp expected(:integer), do: "an integer"
  defp expected(:boolean), do: "true or false"
  defp expected(:integers), do: "a list of integers"
  defp expected({:objects, _properties}), do: "a list of objects"
end
