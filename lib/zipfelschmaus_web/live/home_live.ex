defmodule ZipfelschmausWeb.HomeLive do
  @moduledoc "The start page: the user's lists, the shared ones first. Changes show at once."
  use ZipfelschmausWeb, :live_view

  alias Zipfelschmaus.Shopping

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: Layouts.page_title("Listen")) |> assign_lists()}
  end

  @impl true
  def handle_info({:list_changed, _list_id}, socket), do: {:noreply, assign_lists(socket)}

  defp assign_lists(socket) do
    {shared, private} =
      socket.assigns.current_scope |> Shopping.list_lists() |> Enum.split_with(& &1.shared)

    assign(socket, shared: shared, private: private)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current={:lists}>
      <.header>
        Listen
        <:actions>
          <.button navigate={~p"/lists/new"} variant={:primary} icon="plus" class="max-md:hidden">
            Neue Liste
          </.button>
        </:actions>
      </.header>

      <.empty_state :if={@shared == [] and @private == []} id="lists-empty" title="Noch keine Listen">
        Leg eine Liste an, zum Beispiel für den Supermarkt.
      </.empty_state>

      <div class="flex flex-col gap-8">
        <section :if={@shared != []} id="shared-lists" aria-labelledby="shared-lists-title">
          <.section_heading id="shared-lists-title">Geteilt</.section_heading>
          <.list_rows lists={@shared} />
        </section>
        <section :if={@private != []} id="private-lists" aria-labelledby="private-lists-title">
          <.section_heading id="private-lists-title">Nur für dich</.section_heading>
          <.list_rows lists={@private} />
        </section>
      </div>

      <.fab navigate={~p"/lists/new"} label="Neue Liste" />
    </Layouts.app>
    """
  end

  attr :lists, :list, required: true

  defp list_rows(assigns) do
    ~H"""
    <.list>
      <.list_row
        :for={list <- @lists}
        id={"list-#{list.id}"}
        title={list.name}
        navigate={~p"/lists/#{list}"}
      >
        <:leading><.avatar initials={String.first(list.name)} /></:leading>
        <:meta>{open_text(list.open_count)}</:meta>
      </.list_row>
    </.list>
    """
  end
end
