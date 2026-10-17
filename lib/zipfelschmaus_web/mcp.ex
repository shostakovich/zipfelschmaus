defmodule ZipfelschmausWeb.MCP do
  @moduledoc """
  The MCP server for AI assistants (DECISIONS.md, 0006): JSON-RPC in protocol version
  2026-07-28 only, stateless (no handshake, no session, no batches). Each request names the
  version in `_meta`, and the headers MCP-Protocol-Version, Mcp-Method and, for tools/call,
  Mcp-Name repeat the body. Methods: server/discover, ping, tools/list and tools/call;
  notifications and answers of the client get no reply. See `ZipfelschmausWeb.MCP.Tools` for the
  tools, which run as the user whose secret the call used.
  """

  alias Zipfelschmaus.Users.Scope
  alias ZipfelschmausWeb.MCP.Tools

  @version "2026-07-28"
  @meta_version "io.modelcontextprotocol/protocolVersion"
  @meta_server "io.modelcontextprotocol/serverInfo"
  @ttl :timer.hours(1)

  @instructions """
  ZipfelSchmaus holds the shopping lists of a two-person household. You act as one of the two \
  users: you see their own lists and the lists shared in the household, never the other user's \
  private ones.
  A list shows its open entries by area, in the order of that list's shop; checked-off entries \
  move to "Zuletzt verwendet" (recently used), from where they can be put back.
  An entry is an article on a list with an optional detail, an amount or a note such as "2 l". \
  An article is on a list at most once: adding it again opens its entry again and takes the new \
  detail. Articles and areas have German names; a name the household has not used yet becomes a \
  new article, whose area the app guesses within seconds.
  How to proceed: list_lists for the ids of the lists, read_list before changing a list (reuse \
  the article names it already uses), add_entries to put articles on it, check_off and put_back \
  with the entry ids from read_list. create_list makes a new list; set_article_area moves an \
  article to another area on every list (list_areas names them).\
  """

  defmodule Error do
    @moduledoc "A JSON-RPC error with its HTTP status; `id` is `{:id, value}` if the request had one."
    defstruct [:status, :code, :message, :id, :data]

    @type t :: %__MODULE__{
            status: pos_integer() | nil,
            code: integer(),
            message: String.t(),
            id: {:id, term()} | nil,
            data: term()
          }
  end

  @type request :: %{id: {:id, term()}, method: String.t(), params: map()}

  @doc "The protocol version."
  def version, do: @version

  @doc """
  Reads a message (the body) with the request `headers` (`{name, value}`, names in lower case).
  Nil for a notification or an answer of the client, which get no reply.
  """
  @spec parse(binary(), [{String.t(), String.t()}]) ::
          {:ok, request() | nil} | {:error, Error.t()}
  def parse(body, headers) do
    with :ok <- no_batch(body),
         {:ok, message} <- decode(body),
         id = if(Map.has_key?(message, "id"), do: {:id, message["id"]}),
         {:ok, method} <- method(message, id) do
      if method, do: request(id, method, message["params"], headers), else: {:ok, nil}
    end
  end

  defp request(id, method, params, headers) do
    with {:ok, params} <- params(params, id) do
      if id, do: checked_request(id, method, params, headers), else: {:ok, nil}
    end
  end

  defp checked_request(id, method, params, headers) do
    with :ok <- check_version(params, id),
         :ok <- check_headers(headers, method, params["name"], id),
         do: {:ok, %{id: id, method: method, params: params}}
  end

  defp no_batch(body) do
    if String.starts_with?(String.trim_leading(body), "["),
      do: error(400, -32_600, "JSON-RPC batches are not supported."),
      else: :ok
  end

  defp decode(body) do
    case JSON.decode(body) do
      {:ok, %{} = message} -> check_fields(message)
      {:ok, _other} -> error(400, -32_700, "Invalid JSON: expected an object")
      {:error, reason} -> error(400, -32_700, "Invalid JSON: #{reason(reason)}")
    end
  end

  defp check_fields(message) do
    case Enum.find(["jsonrpc", "method"], &(not (is_nil(message[&1]) or is_binary(message[&1])))) do
      nil -> {:ok, message}
      field -> error(400, -32_700, "Invalid JSON: #{field}: expected a string")
    end
  end

  defp reason({:unexpected_end, _offset}), do: "unexpected end of input"
  defp reason({:invalid_byte, offset, byte}), do: "invalid byte #{inspect(<<byte>>)} at #{offset}"

  defp reason({:unexpected_sequence, offset, bytes}),
    do: "unexpected #{inspect(bytes)} at #{offset}"

  defp reason(other), do: inspect(other)

  # An answer of the client has no method but a result or an error.
  defp method(message, id) do
    case message["method"] do
      method when method not in [nil, ""] ->
        if message["jsonrpc"] == "2.0",
          do: {:ok, method},
          else: error(400, -32_600, ~s(jsonrpc must be "2.0".), id)

      _none ->
        if Map.has_key?(message, "result") or Map.has_key?(message, "error"),
          do: {:ok, nil},
          else: error(400, -32_600, "Field method is missing.", id)
    end
  end

  defp params(nil, _id), do: {:ok, %{}}

  defp params(%{} = params, id) do
    cond do
      not (is_nil(params["_meta"]) or is_map(params["_meta"])) ->
        error(400, -32_602, "Invalid params: _meta: expected an object", id)

      not (is_nil(params["name"]) or is_binary(params["name"])) ->
        error(400, -32_602, "Invalid params: name: expected a string", id)

      true ->
        {:ok, params}
    end
  end

  defp params(_params, id), do: error(400, -32_602, "Invalid params: expected an object", id)

  defp check_version(params, id) do
    case (params["_meta"] || %{})[@meta_version] do
      @version ->
        :ok

      version when version == "" or not (is_nil(version) or is_binary(version)) ->
        error(400, -32_602, "_meta.#{@meta_version} must be a non-empty string.", id)

      version ->
        {:error,
         %Error{
           status: 400,
           code: -32_022,
           message: "Unsupported protocol version.",
           id: id,
           data: %{supported: [@version], requested: version}
         }}
    end
  end

  defp check_headers(headers, method, tool, id) do
    checks = [{"MCP-Protocol-Version", @version, "_meta"}, {"Mcp-Method", method, "method"}]

    checks =
      if method == "tools/call",
        do: checks ++ [{"Mcp-Name", tool || "", "params.name"}],
        else: checks

    Enum.reduce_while(checks, :ok, fn {name, expected, source}, :ok ->
      case check_header(headers, name, expected, source) do
        :ok -> {:cont, :ok}
        {:mismatch, message} -> {:halt, error(400, -32_020, "Header mismatch: " <> message, id)}
      end
    end)
  end

  defp check_header(headers, name, expected, source) do
    value =
      case List.keyfind(headers, String.downcase(name), 0) do
        {_name, value} -> String.trim(value)
        nil -> ""
      end

    value = if name == "Mcp-Name" and value != "", do: decode_header_value(value), else: value

    cond do
      value == "" ->
        {:mismatch, "header #{name} is missing."}

      value == :invalid ->
        {:mismatch, "#{name} is not valid Base64."}

      value != expected ->
        {:mismatch, "#{name} #{inspect(value)} does not match #{source} #{inspect(expected)}."}

      true ->
        :ok
    end
  end

  @doc ~s(A header value, decoded if it is written as "=?base64?…?="; `:invalid` if that fails.)
  def decode_header_value("=?base64?" <> rest = value) when byte_size(rest) >= 2 do
    encoded = binary_part(rest, 0, byte_size(rest) - 2)

    cond do
      not String.ends_with?(rest, "?=") -> value
      not (encoded =~ ~r/\A[A-Za-z0-9+\/]*={0,2}\z/) -> :invalid
      String.ends_with?(encoded, "=") -> decode64(encoded, rem(byte_size(encoded), 4) == 0, true)
      true -> decode64(encoded, rem(byte_size(encoded), 4) != 1, false)
    end
  end

  def decode_header_value(value), do: value

  defp decode64(_encoded, false, _padding), do: :invalid

  defp decode64(encoded, true, padding) do
    case Base.decode64(encoded, padding: padding) do
      {:ok, decoded} -> decoded
      :error -> :invalid
    end
  end

  @doc "Answers a request as the user of `scope`: `{:ok, result}` or `{:error, %Error{}}`."
  def dispatch(request, scope)

  def dispatch(%{method: "server/discover"}, %Scope{}) do
    result(%{
      supportedVersions: [@version],
      capabilities: %{tools: %{listChanged: false}},
      instructions: @instructions,
      ttlMs: @ttl,
      cacheScope: "public"
    })
  end

  def dispatch(%{method: "ping"}, %Scope{}), do: result(%{})

  def dispatch(%{method: "tools/list"}, %Scope{}),
    do: result(%{tools: Tools.list(), ttlMs: @ttl, cacheScope: "public"})

  def dispatch(%{method: "tools/call", id: id, params: params}, %Scope{} = scope) do
    name = params["name"] || ""

    case Tools.call(name, params["arguments"], scope) do
      :unknown -> error(200, -32_602, "Unknown tool: #{name}", id)
      {text, error?} -> result(%{content: [%{type: "text", text: text}], isError: error?})
    end
  end

  def dispatch(%{method: method, id: id}, %Scope{}),
    do: error(404, -32_601, "Unknown method: #{method}", id)

  defp result(result) do
    server = %{
      name: "zipfelschmaus",
      title: "ZipfelSchmaus – shopping lists",
      version: :zipfelschmaus |> Application.spec(:vsn) |> to_string()
    }

    {:ok, Map.merge(result, %{resultType: "complete", _meta: %{@meta_server => server}})}
  end

  defp error(status, code, message, id \\ nil),
    do: {:error, %Error{status: status, code: code, message: message, id: id}}
end
