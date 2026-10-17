defmodule ZipfelschmausWeb.ListSettingsLive do
  @moduledoc """
  A new list, or the settings of one: name and sharing, and deleting it. Only the owner reaches
  the settings.
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
        |> assign(page_title: Layouts.page_title("Liste bearbeiten"), list: list)
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
    </Layouts.app>
    """
  end
end
