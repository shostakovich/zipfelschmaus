defmodule ZipfelschmausWeb.MCPCase do
  @moduledoc """
  Test case for calls to the MCP endpoint, allowed from localhost. Each user's endpoint is
  `/mcp/<their secret>`; `mcp_path/1` creates it.
  """

  use ExUnit.CaseTemplate

  import ExUnit.Assertions
  import Plug.Conn

  alias Zipfelschmaus.{Network, Users}
  alias ZipfelschmausWeb.MCP

  @endpoint ZipfelschmausWeb.Endpoint

  using do
    quote do
      use ZipfelschmausWeb.ConnCase

      import ZipfelschmausWeb.MCPCase
    end
  end

  setup do
    configure_mcp(allowed_cidrs: "127.0.0.1/32, ::1/128")
    :ok
  end

  @doc "Configures the MCP for the running test; CIDR lists as text."
  def configure_mcp(opts) do
    previous = Application.get_env(:zipfelschmaus, :mcp)
    networks = &elem(Network.parse_list(&1), 1)

    Application.put_env(:zipfelschmaus, :mcp,
      allowed_cidrs: networks.(Keyword.get(opts, :allowed_cidrs, "")),
      trusted_proxies: networks.(Keyword.get(opts, :trusted_proxies, ""))
    )

    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:zipfelschmaus, :mcp, previous) end)
  end

  @doc "The endpoint of `user`, with a new secret."
  def mcp_path(user), do: "/mcp/" <> Users.create_mcp_secret(user)

  @doc "A JSON-RPC message; `id: :none` makes it a notification, `version: nil` leaves out _meta."
  def message(method, params \\ %{}, opts \\ []) do
    params =
      case Keyword.get(opts, :version, MCP.version()) do
        nil ->
          params

        version ->
          Map.put(params, "_meta", %{"io.modelcontextprotocol/protocolVersion" => version})
      end

    message = %{"jsonrpc" => "2.0", "method" => method, "params" => params}

    case Keyword.get(opts, :id, 1) do
      :none -> JSON.encode!(message)
      id -> JSON.encode!(Map.put(message, "id", id))
    end
  end

  @doc "The protocol headers of a call."
  def protocol_headers(method, name \\ nil) do
    [{"mcp-protocol-version", MCP.version()}, {"mcp-method", method}] ++
      if(name, do: [{"mcp-name", name}], else: [])
  end

  @doc "POSTs a body to `path` with headers (no content type unless given)."
  def post_mcp(path, body, opts \\ []) do
    headers = Keyword.get(opts, :headers, [{"content-type", "application/json"}])

    "POST"
    |> Plug.Test.conn(path, body)
    |> Map.put(:remote_ip, Keyword.get(opts, :remote_ip, {127, 0, 0, 1}))
    |> then(
      &Enum.reduce(headers, &1, fn {name, value}, conn -> put_req_header(conn, name, value) end)
    )
    |> @endpoint.call(@endpoint.init([]))
  end

  @doc "A request with matching headers."
  def rpc(path, method, params \\ %{}, opts \\ []) do
    name = if method == "tools/call", do: params["name"]
    headers = [{"content-type", "application/json"} | protocol_headers(method, name)]

    post_mcp(
      path,
      message(method, params, opts),
      Keyword.put(opts, :headers, headers ++ Keyword.get(opts, :extra, []))
    )
  end

  @doc "Calls a tool; `arguments` is a JSON-encodable term or `:none`."
  def call_tool(path, name, arguments \\ %{}) do
    params =
      if arguments == :none,
        do: %{"name" => name},
        else: %{"name" => name, "arguments" => arguments}

    rpc(path, "tools/call", params)
  end

  def json(conn), do: JSON.decode!(conn.resp_body)
  def result(conn), do: json(conn)["result"]

  def error(conn) do
    %{"error" => %{"code" => code, "message" => message}} = json(conn)
    {code, message}
  end

  @doc "The text of a tool result, which must (not) be an error."
  def text(conn, error? \\ false) do
    assert conn.status == 200, conn.resp_body
    %{"content" => [%{"type" => "text", "text" => text}], "isError" => ^error?} = result(conn)
    text
  end

  @doc "The decoded result of a tool that worked."
  def ok(path, name, arguments \\ %{}),
    do: path |> call_tool(name, arguments) |> text() |> JSON.decode!()

  @doc "The message of a refused tool call."
  def refusal(path, name, arguments), do: path |> call_tool(name, arguments) |> text(true)
end
