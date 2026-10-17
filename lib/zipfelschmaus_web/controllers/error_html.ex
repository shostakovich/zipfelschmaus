defmodule ZipfelschmausWeb.ErrorHTML do
  @moduledoc "German error pages in the app's shell, with the way back to the start page."
  use ZipfelschmausWeb, :html

  alias Plug.Conn.Status

  @messages %{
    400 => "Ungültige Anfrage.",
    403 =>
      "Diese Anfrage kam von einer fremden Seite und wurde abgelehnt. " <>
        "Bitte lade die Seite neu und versuche es noch einmal.",
    404 => "Seite nicht gefunden.",
    405 => "Diese Seite kennt die verwendete Methode nicht.",
    413 =>
      "Die gesendeten Daten sind zu groß. Bitte kürze die Eingaben und versuche es noch einmal.",
    500 => "Da ist etwas schiefgegangen."
  }

  @doc "The page's message for a status."
  def message(status), do: Map.get(@messages, status, Status.reason_phrase(status))

  def render(_template, assigns) do
    message = message(assigns.status)
    conn = assigns[:conn]

    assigns =
      assign(assigns,
        message: message,
        page_title: Layouts.page_title(message),
        csp_nonce: conn && conn.assigns[:csp_nonce]
      )

    ~H"""
    <Layouts.root {assigns} inner_content={page(assigns)} />
    """
  end

  defp page(assigns) do
    ~H"""
    <Layouts.app flash={%{}}>
      <.header>{@message}</.header>
      <.button href={~p"/"}>Zur Startseite</.button>
    </Layouts.app>
    """
  end
end
