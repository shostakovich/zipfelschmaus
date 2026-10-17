defmodule ZipfelschmausWeb.MCPPlugTest do
  use ZipfelschmausWeb.MCPCase

  @moduletag :capture_log

  import ExUnit.CaptureLog
  import Zipfelschmaus.UsersFixtures

  @meta %{
    "io.modelcontextprotocol/serverInfo" => %{
      "name" => "zipfelschmaus",
      "title" => "ZipfelSchmaus – shopping lists",
      "version" => to_string(Application.spec(:zipfelschmaus, :vsn))
    }
  }

  setup do
    user = user_fixture()
    %{user: user, path: mcp_path(user)}
  end

  defp json_error(conn, status, code, message) do
    assert conn.status == status
    assert get_resp_header(conn, "content-type") == ["application/json"]
    assert json(conn)["jsonrpc"] == "2.0"
    assert error(conn) == {code, message}
    json(conn)
  end

  defp plain(conn, status, body) do
    assert {conn.status, conn.resp_body} == {status, body}
    assert get_resp_header(conn, "content-type") == ["text/plain; charset=utf-8"]
  end

  defp request(method, path) do
    dispatch(build_conn(), @endpoint, method, path, nil)
  end

  test "server/discover explains the server, cached for an hour", %{path: path} do
    conn = rpc(path, "server/discover", %{}, id: "0")

    assert conn.status == 200
    assert json(conn)["id"] == "0"

    assert %{
             "_meta" => @meta,
             "cacheScope" => "public",
             "capabilities" => %{"tools" => %{"listChanged" => false}},
             "resultType" => "complete",
             "supportedVersions" => ["2026-07-28"],
             "ttlMs" => 3_600_000,
             "instructions" => instructions
           } = result(conn)

    assert instructions =~ "never the other user's private ones"
  end

  test "tools/list names the tools with strict schemas and annotations", %{path: path} do
    result = result(rpc(path, "tools/list"))

    assert {result["ttlMs"], result["cacheScope"], result["_meta"]} ==
             {3_600_000, "public", @meta}

    tools = result["tools"]

    assert Enum.map(tools, & &1["name"]) ==
             ~w(list_lists read_list list_areas add_entries check_off put_back create_list set_article_area)

    for tool <- tools do
      read? = tool["name"] in ~w(list_lists read_list list_areas)
      assert Enum.sort(Map.keys(tool)) == ~w(annotations description inputSchema name title)
      assert tool["annotations"]["readOnlyHint"] == read?
      assert tool["annotations"]["destructiveHint"] == false

      assert {tool["inputSchema"]["type"], tool["inputSchema"]["additionalProperties"]} ==
               {"object", false}
    end

    add = Enum.find(tools, &(&1["name"] == "add_entries"))["inputSchema"]
    assert add["required"] == ["list_id", "entries"]

    assert %{
             "type" => "array",
             "items" => %{"required" => ["article"], "additionalProperties" => false}
           } =
             add["properties"]["entries"]
  end

  describe "the protocol" do
    test "ping answers an empty result", %{path: path} do
      assert result(rpc(path, "ping")) == %{"_meta" => @meta, "resultType" => "complete"}
    end

    test "only version 2026-07-28 is spoken", %{path: path} do
      body =
        json_error(
          rpc(path, "ping", %{}, id: "a-1", version: "2025-06-18"),
          400,
          -32_022,
          "Unsupported protocol version."
        )

      assert body["error"]["data"] == %{
               "supported" => ["2026-07-28"],
               "requested" => "2025-06-18"
             }

      json_error(rpc(path, "initialize"), 404, -32_601, "Unknown method: initialize")
    end

    test "unknown tools and mismatched headers", %{path: path} do
      assert json_error(call_tool(path, "nope"), 200, -32_602, "Unknown tool: nope")["id"] == 1

      conn =
        post_mcp(path, message("tools/call", %{"name" => "list_lists"}),
          headers: [
            {"content-type", "application/json"} | protocol_headers("tools/call", "read_list")
          ]
        )

      json_error(
        conn,
        400,
        -32_020,
        ~s(Header mismatch: Mcp-Name "read_list" does not match params.name "list_lists".)
      )
    end

    test "notifications get 202 without a body", %{path: path} do
      conn = post_mcp(path, message("notifications/cancelled", %{}, id: :none, version: nil))
      assert {conn.status, conn.resp_body} == {202, ""}
    end

    test "malformed messages", %{path: path} do
      json_error(
        post_mcp(path, ~s([{"jsonrpc":"2.0","id":1,"method":"ping"}])),
        400,
        -32_600,
        "JSON-RPC batches are not supported."
      )

      assert {-32_700, "Invalid JSON" <> _detail} = error(post_mcp(path, "{broken"))
    end
  end

  describe "the transport" do
    test "takes JSON only, up to 1 MiB", %{path: path} do
      ping = message("ping")
      headers = &[{"content-type", &1} | protocol_headers("ping")]

      json_error(
        post_mcp(path, ping, headers: headers.("text/plain")),
        415,
        -32_600,
        "Content-Type must be application/json."
      )

      exact = ping <> String.duplicate(" ", 1_048_576 - byte_size(ping))
      assert post_mcp(path, exact, headers: headers.("application/json")).status == 200

      json_error(
        post_mcp(path, exact <> " ", headers: headers.("application/json")),
        413,
        -32_600,
        "Message too large."
      )
    end

    test "answers POST only", %{path: path} do
      for method <- ~w(GET PUT DELETE) do
        conn = request(method, path)
        assert {conn.status, get_resp_header(conn, "allow")} == {405, ["POST"]}
      end
    end

    test "refuses any browser", %{path: path} do
      json_error(
        post_mcp(path, message("ping"),
          headers: [{"origin", "https://claude.ai"}, {"content-type", "application/json"}]
        ),
        403,
        -32_000,
        "Access from a browser is not allowed."
      )
    end

    test "a wrong or replaced secret is a plain 404", %{user: user, path: path} do
      "/mcp/" <> secret = path
      upcased = "/mcp/" <> String.upcase(secret)

      for wrong <- ["/mcp/wrong", path <> "x", path <> "/", upcased, "/mcp/", "/mcp"] do
        plain(post_mcp(wrong, message("ping")), 404, "Not Found\n")
        assert request("GET", wrong).status == 404
      end

      new_path = mcp_path(user)
      plain(post_mcp(path, message("ping")), 404, "Not Found\n")
      assert rpc(new_path, "ping").status == 200
    end

    test "is outside the web app: no session cookie", %{path: path} do
      conn = rpc(path, "ping", %{}, extra: [{"cookie", "_zipfelschmaus_key=broken"}])

      assert conn.status == 200
      assert get_resp_header(conn, "set-cookie") == []
    end
  end

  describe "access by client address" do
    test "takes the address of the connection without a trusted proxy", %{path: path} do
      configure_mcp(allowed_cidrs: "10.0.0.0/8")
      not_allowed = "Access from this address is not allowed."

      json_error(rpc(path, "ping"), 403, -32_000, not_allowed)

      json_error(
        rpc(path, "ping", %{}, extra: [{"x-forwarded-for", "10.1.2.3"}]),
        403,
        -32_000,
        not_allowed
      )

      assert rpc(path, "ping", %{}, remote_ip: {10, 9, 9, 9}).status == 200
    end

    test "behind a trusted proxy the rightmost untrusted X-Forwarded-For hop counts",
         %{path: path} do
      configure_mcp(allowed_cidrs: "10.0.0.0/8", trusted_proxies: "127.0.0.1")
      status = fn headers -> rpc(path, "ping", %{}, extra: headers).status end

      assert status.([]) == 403
      assert status.([{"x-forwarded-for", "10.1.2.3"}]) == 200
      assert status.([{"x-forwarded-for", "10.1.2.3, 6.6.6.6"}]) == 403
      assert status.([{"x-real-ip", "10.9.9.9"}]) == 200
    end
  end

  test "logs calls with the user, but never the secret", %{user: user, path: path} do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)
    "/mcp/" <> secret = path

    log =
      capture_log([level: :info], fn ->
        assert rpc(path, "ping").status == 200
        assert rpc("/mcp/wrong", "ping").status == 404
        assert call_tool(path, "read_list", %{"list_id" => 0}).status == 200
      end)

    assert log =~ ~s(user=#{user.id} method="ping" status=200)
    assert log =~ "wrong secret"
    assert log =~ ~s(tool="read_list" status=200)
    assert log =~ ~s(tool_error="Unknown list 0)
    refute log =~ secret
  end
end
