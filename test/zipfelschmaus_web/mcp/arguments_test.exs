defmodule ZipfelschmausWeb.MCP.ArgumentsTest do
  use ExUnit.Case, async: true

  alias ZipfelschmausWeb.MCP.{Arguments, ToolError}

  @properties [
    {:list_id, :integer, required: true},
    {:shared, :boolean, []},
    {:entry_ids, :integers, []},
    {:entries, {:objects, [{:article, :string, required: true}, {:detail, :string, []}]}, []}
  ]

  defp refusal(arguments) do
    error = assert_raise ToolError, fn -> Arguments.decode!(arguments, @properties) end
    error.message
  end

  test "decodes the known properties; null, blank and empty count as not given" do
    assert Arguments.decode!(
             %{
               "list_id" => 3,
               "entry_ids" => [],
               "entries" => [
                 %{"article" => "Milch", "detail" => " "},
                 %{"article" => "Brot", "detail" => nil}
               ]
             },
             @properties
           ) == %{
             list_id: 3,
             shared: false,
             entry_ids: [],
             entries: [%{article: "Milch", detail: nil}, %{article: "Brot", detail: nil}]
           }
  end

  test "names the offending property" do
    assert refusal(nil) == "Invalid arguments: list_id: missing"
    assert refusal([]) == "Invalid arguments: expected an object"
    assert refusal(%{"list_id" => "3"}) == "Invalid arguments: list_id: expected an integer"
    assert refusal(%{"list_id" => 3, "x" => 1}) == "Invalid arguments: x: unknown argument"

    assert refusal(%{"list_id" => 3, "entry_ids" => [1, "2"]}) ==
             "Invalid arguments: entry_ids: expected a list of integers"

    assert refusal(%{
             "list_id" => 3,
             "entries" => [%{"article" => "Milch"}, %{"detail" => "2 l"}]
           }) ==
             "Invalid arguments: entries[1].article: missing"

    assert refusal(%{"list_id" => 3, "entries" => ["Milch"]}) ==
             "Invalid arguments: entries[0]: expected an object"

    assert refusal(%{"list_id" => 3, "entries" => "Milch"}) ==
             "Invalid arguments: entries: expected a list of objects"
  end
end
