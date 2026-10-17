defmodule Zipfelschmaus.LanguageModel.ChatAPITest do
  use ExUnit.Case

  alias Zipfelschmaus.LanguageModel.ChatAPI

  defmodule Server do
    @moduledoc "A chat API that tells the test about each request and gives a fixed response."
    @behaviour Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, {test, status, response}) do
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      send(
        test,
        {:request, conn.request_path, Plug.Conn.get_req_header(conn, "authorization"),
         JSON.decode!(body)}
      )

      Plug.Conn.send_resp(conn, status, response)
    end
  end

  @schema %{type: "object", properties: %{area: %{type: "string", enum: ["Drogerie"]}}}

  setup do
    previous = Application.get_env(:zipfelschmaus, ChatAPI)
    on_exit(fn -> Application.put_env(:zipfelschmaus, ChatAPI, previous) end)
  end

  test "asks for an answer by the schema at temperature 0, without thinking" do
    serve(200, completion(%{"content" => ~s({"area": "Drogerie"})}), api_key: "geheim")

    assert ChatAPI.answer("Sort it.", "Spülmaschinentabs", @schema) ==
             {:ok, ~s({"area": "Drogerie"})}

    assert_received {:request, "/v1/chat/completions", ["Bearer geheim"], body}

    assert %{
             "model" => "gemma",
             "temperature" => 0,
             "reasoning_effort" => "none",
             "messages" => [
               %{"role" => "system", "content" => "Sort it."},
               %{"role" => "user", "content" => "Spülmaschinentabs"}
             ],
             "response_format" => %{
               "type" => "json_schema",
               "json_schema" => %{"strict" => true, "schema" => %{"type" => "object"}}
             }
           } = body
  end

  test "lets a thinking model think and reads its answer from reasoning_content" do
    serve(200, completion(%{"content" => "", "reasoning_content" => "{}"}), thinking: true)

    assert ChatAPI.answer("Sort it.", "Milch", @schema) == {:ok, "{}"}
    assert_received {:request, _path, [], body}
    refute Map.has_key?(body, "reasoning_effort")
  end

  test "fails on an error status, an odd response or no server" do
    serve(503, "busy")
    assert ChatAPI.answer("Sort it.", "Milch", @schema) == {:error, {:http_status, 503}}

    serve(200, ~s({"choices": []}))
    assert ChatAPI.answer("Sort it.", "Milch", @schema) == {:error, :invalid_response}

    configure("http://127.0.0.1:1/v1")
    assert ChatAPI.answer("Sort it.", "Milch", @schema) == {:error, :unreachable}
  end

  test "is available only with URL and model" do
    configure(nil)
    refute ChatAPI.available?()

    configure("http://127.0.0.1:1/v1")
    assert ChatAPI.available?()
  end

  defp serve(status, response, options \\ []) do
    server =
      start_supervised!(
        {Bandit,
         plug: {Server, {self(), status, response}}, port: 0, ip: :loopback, startup_log: false},
        id: make_ref()
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    configure("http://127.0.0.1:#{port}/v1/", options)
  end

  defp configure(url, options \\ []),
    do: Application.put_env(:zipfelschmaus, ChatAPI, [url: url, model: "gemma"] ++ options)

  defp completion(message), do: JSON.encode!(%{"choices" => [%{"message" => message}]})
end
