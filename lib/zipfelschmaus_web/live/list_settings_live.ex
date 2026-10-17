defmodule ZipfelschmausWeb.ListSettingsLive do
  @moduledoc """
  A new list, or the settings of one: name and sharing, its area order, and deleting it. Only
  the owner reaches the settings. A move in the area order is saved at once.
  """
  use ZipfelschmausWeb, :live_view

  alias Zipfelschmaus.Shopping
  alias Zipfelschmaus.Shopping.ShoppingList

  @impl true
  def mount(params, _session, socket), do: {:ok, init(socket, socket.assigns.live_action, params)}

  defp init(socket, :new, _params) do
    socket
    |> assign(page_title: Layouts.page_title("Neue Liste"), list: %ShoppingList{})
    |> assign_form(Shopping.change_list(%ShoppingList{}))
  end

  defp init(socket, :edit, %{"id" => id}) do
    case Shopping.get_own_list(socket.assigns.current_scope, id) do
      nil ->
        socket
        |> put_flash(:error, "Diese Liste gibt es für dich nicht.")
        |> push_navigate(to: ~p"/")

      list ->
        socket
        |> assign(page_title: Layouts.page_title("Liste bearbeiten"))
        |> assign_list(list)
        |> assign_form(Shopping.change_list(list))
    end
  end

  @impl true
  def handle_event("validate", %{"list" => params}, socket) do
    changeset = Shopping.change_list(socket.assigns.list, params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"list" => params}, socket) do
    case save(socket, socket.assigns.live_action, params) do
      {:ok, list} ->
        {:noreply, push_navigate(socket, to: ~p"/lists/#{list}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("move_area", %{"id" => area_id, "direction" => direction}, socket) do
    %{current_scope: scope, list: list} = socket.assigns

    case Shopping.move_area(scope, list, area_id, direction(direction)) do
      {:ok, list} -> {:noreply, assign_list(socket, list)}
      {:error, :not_found} -> {:noreply, socket}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, list} = Shopping.delete_list(socket.assigns.current_scope, socket.assigns.list)

    {:noreply,
     socket
     |> put_flash(:info, "Liste „#{list.name}“ gelöscht.")
     |> push_navigate(to: ~p"/")}
  end

  defp save(socket, :new, params), do: Shopping.create_list(socket.assigns.current_scope, params)

  defp save(socket, :edit, params),
    do: Shopping.update_list(socket.assigns.current_scope, socket.assigns.list, params)

  defp direction("up"), do: :up
  defp direction("down"), do: :down

  defp assign_list(socket, list),
    do: assign(socket, list: list, areas: Shopping.list_areas(list))

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset, as: :list))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current={:lists}>
      <.header back={if @live_action == :edit, do: ~p"/lists/#{@list}", else: ~p"/"}>
        {if @live_action == :edit, do: "Liste bearbeiten", else: "Neue Liste"}
      </.header>

      <.form for={@form} id="list-form" phx-change="validate" phx-submit="save" class="grid gap-4">
        <.input field={@form[:name]} label="Name" required maxlength="60" autocomplete="off" />
        <.input
          field={@form[:shared]}
          type="toggle"
          label="Teilen"
          help="Eine geteilte Liste sehen und bearbeiten alle im Haushalt live mit."
        />

        <.action_bar>
          <:secondary :if={@live_action == :edit}>
            <.button
              id="delete-list"
              variant={:danger_outline}
              icon="trash-2"
              confirm={"Liste „#{@list.name}“ löschen?"}
              confirm_text="Ihre Einträge werden mit gelöscht."
              phx-click="delete"
            >
              Liste löschen
            </.button>
          </:secondary>
          <.button navigate={if @live_action == :edit, do: ~p"/lists/#{@list}", else: ~p"/"}>
            Abbrechen
          </.button>
          <.button type="submit" variant={:primary} phx-disable-with="Speichert …">
            {if @live_action == :edit, do: "Speichern", else: "Anlegen"}
          </.button>
        </.action_bar>
      </.form>

      <section
        :if={@live_action == :edit}
        id="area-order"
        aria-labelledby="area-order-title"
        class="mt-8"
      >
        <.section_heading id="area-order-title">Reihenfolge der Bereiche</.section_heading>
        <p class="mb-2 text-sm text-base-content/70">So, wie du durch den Laden gehst.</p>
        <.list>
          <.list_row
            :for={{area, index} <- Enum.with_index(@areas)}
            id={"area-#{area.key}"}
            title={area.name}
          >
            <:action
              id={"area-#{area.key}-up"}
              label="Nach oben"
              icon="chevron-up"
              disabled={index == 0}
              on_click={JS.push("move_area", value: %{id: area.id, direction: "up"})}
            />
            <:action
              id={"area-#{area.key}-down"}
              label="Nach unten"
              icon="chevron-down"
              disabled={index == length(@areas) - 1}
              on_click={JS.push("move_area", value: %{id: area.id, direction: "down"})}
            />
          </.list_row>
        </.list>
      </section>
    </Layouts.app>
    """
  end
end
