defmodule ZipfelschmausWeb.HomeLive do
  @moduledoc "The start page; a placeholder until the lists arrive."
  use ZipfelschmausWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: Layouts.page_title("Listen"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>Listen</.header>
      <.empty_state id="lists-empty" title="Noch keine Listen">
        Hier stehen bald eure Einkaufslisten.
      </.empty_state>
    </Layouts.app>
    """
  end
end
