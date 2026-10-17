defmodule Zipfelschmaus.LanguageModel.ChatAPI do
  @moduledoc """
  Any OpenAI-compatible chat API, such as Ollama or LM Studio on the home server: base URL,
  model and an optional key from `MODEL_URL`, `MODEL` and `MODEL_KEY`, at temperature 0. A
  thinking model is asked not to think, by `reasoning_effort: "none"`, unless `MODEL_THINKING`
  is on.
  """
  @behaviour Zipfelschmaus.LanguageModel

  alias Zipfelschmaus.TLS

  # The model may be busy with another app's request first.
  @timeout 120_000

  @impl true
  def available?, do: present?(config(:url)) and present?(config(:model))

  @impl true
  def answer(instructions, question, schema) do
    body =
      Map.merge(thinking_options(), %{
        model: config(:model),
        temperature: 0,
        messages: [
          %{role: "system", content: instructions},
          %{role: "user", content: question}
        ],
        response_format: %{
          type: "json_schema",
          json_schema: %{name: "answer", strict: true, schema: schema}
        }
      })

    case post_json(url(), body) do
      {:ok, 200, response} -> content(response)
      {:ok, status, _response} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp thinking_options, do: if(config(:thinking), do: %{}, else: %{reasoning_effort: "none"})

  defp url, do: String.trim_trailing(config(:url), "/") <> "/chat/completions"

  defp post_json(url, body) do
    request = {to_charlist(url), headers(), ~c"application/json", JSON.encode!(body)}

    http_options = [
      timeout: @timeout,
      connect_timeout: 15_000,
      ssl: TLS.verify_options(URI.parse(url).host || ""),
      autoredirect: false
    ]

    case :httpc.request(:post, request, http_options, body_format: :binary) do
      {:ok, {{_version, status, _reason}, _headers, body}} -> {:ok, status, body}
      {:error, :timeout} -> {:error, :timeout}
      {:error, _reason} -> {:error, :unreachable}
    end
  end

  defp headers do
    if present?(config(:api_key)),
      do: [{~c"authorization", to_charlist("Bearer " <> config(:api_key))}],
      else: []
  end

  # LM Studio puts a thinking model's constrained answer into `reasoning_content`.
  defp content(response) do
    with {:ok, %{"choices" => [%{"message" => message} | _]}} <- JSON.decode(response),
         answer when is_binary(answer) <- message_answer(message) do
      {:ok, answer}
    else
      _other -> {:error, :invalid_response}
    end
  end

  defp message_answer(%{"content" => content} = message) when content in [nil, ""],
    do: message["reasoning_content"]

  defp message_answer(%{"content" => content}), do: content
  defp message_answer(_message), do: nil

  defp present?(value), do: value not in [nil, ""]

  defp config(key), do: Application.get_env(:zipfelschmaus, __MODULE__, [])[key]
end
