defmodule ZipfelschmausWeb.ListLive do
  @moduledoc """
  A list while shopping: the open entries grouped by area in the list's area order, a tap checks
  one off; below them "Zuletzt verwendet", where a tap puts one back; at the bottom the field
  that adds articles. Each entry's menu changes its detail or its article's area. Changes by
  others show at once; a list that is deleted or no longer shared sends the reader back to the
  start page.
  """
  use ZipfelschmausWeb, :live_view

  alias Zipfelschmaus.{Catalog, Shopping}
  alias Zipfelschmaus.Shopping.ShoppingList
  alias ZipfelschmausWeb.OfflineCopy

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Shopping.get_list(socket.assigns.current_scope, id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Diese Liste gibt es für dich nicht.")
         |> push_navigate(to: ~p"/")}

      list ->
        if connected?(socket), do: Shopping.subscribe_list(list.id)
        {:ok, socket |> assign_new_entry_form() |> close_edit() |> assign_list(list)}
    end
  end

  @impl true
  def handle_event("check_off", %{"id" => id}, socket),
    do: {:noreply, reload_unless_ok(socket, Shopping.check_off(socket.assigns.current_scope, id))}

  def handle_event("put_back", %{"id" => id}, socket),
    do: {:noreply, reload_unless_ok(socket, Shopping.put_back(socket.assigns.current_scope, id))}

  def handle_event("change_entry", %{"entry" => params}, socket) do
    {:noreply, assign(socket, :form, to_form(Shopping.change_new_entry(params), as: :entry))}
  end

  def handle_event("add", %{"entry" => params}, socket) do
    case Shopping.add_entry(socket.assigns.current_scope, socket.assigns.list, params) do
      {:ok, _entry} ->
        {:noreply, assign_new_entry_form(socket)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :entry))}

      {:error, :not_found} ->
        {:noreply, reload(socket)}
    end
  end

  def handle_event("edit_detail", %{"id" => id}, socket),
    do: {:noreply, open_edit(socket, id, :detail)}

  def handle_event("edit_area", %{"id" => id}, socket),
    do: {:noreply, open_edit(socket, id, :area)}

  def handle_event("close_edit", _params, socket), do: {:noreply, close_edit(socket)}

  def handle_event("validate_detail", %{"edit" => params}, socket) do
    changeset = Shopping.change_detail(socket.assigns.editing, params)
    {:noreply, assign(socket, :edit_form, to_form(changeset, as: :edit, action: :validate))}
  end

  def handle_event("save_detail", %{"edit" => params}, socket) do
    case Shopping.update_detail(socket.assigns.current_scope, socket.assigns.editing.id, params) do
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :edit_form, to_form(changeset, as: :edit))}

      saved_or_gone ->
        {:noreply, socket |> close_edit() |> reload_unless_ok(saved_or_gone)}
    end
  end

  def handle_event("save_area", %{"edit" => %{"area_id" => area_id}}, socket) do
    result = Shopping.set_area(socket.assigns.current_scope, socket.assigns.editing.id, area_id)
    {:noreply, socket |> close_edit() |> reload_unless_ok(result)}
  end

  @impl true
  def handle_info({:list_changed, _list_id}, socket), do: {:noreply, reload(socket)}

  # A change that worked comes back as a broadcast, which reloads.
  defp reload_unless_ok(socket, {:ok, _changed}), do: socket
  defp reload_unless_ok(socket, {:error, _reason}), do: reload(socket)

  defp reload(socket) do
    case Shopping.get_list(socket.assigns.current_scope, socket.assigns.list.id) do
      nil ->
        socket
        |> put_flash(
          :error,
          "Die Liste „#{socket.assigns.list.name}“ gibt es für dich nicht mehr."
        )
        |> push_navigate(to: ~p"/")

      list ->
        assign_list(socket, list)
    end
  end

  defp open_edit(socket, entry_id, field) do
    case Shopping.get_entry(socket.assigns.current_scope, entry_id) do
      nil -> reload(socket)
      entry -> assign(socket, editing: entry, edit: field, edit_form: edit_form(entry, field))
    end
  end

  defp edit_form(entry, :detail), do: to_form(Shopping.change_detail(entry), as: :edit)

  defp edit_form(entry, :area),
    do: to_form(%{"area_id" => entry.article.area_id}, as: :edit)

  defp close_edit(socket), do: assign(socket, editing: nil, edit: nil, edit_form: nil)

  defp assign_list(socket, %ShoppingList{} = list) do
    open = Shopping.list_open_entries(list)
    recent = Shopping.list_recent_entries(list)

    socket
    |> assign(
      page_title: Layouts.page_title(list.name),
      list: list,
      owner?: list.owner_id == socket.assigns.current_scope.user.id,
      open_count: length(open),
      areas: Enum.chunk_by(open, & &1.article.area_id),
      area_options: for(area <- Shopping.list_areas(list), do: {area.name, area.id}),
      recent: recent,
      article_options: article_options(recent)
    )
    |> OfflineCopy.push()
  end

  defp assign_new_entry_form(socket),
    do: assign(socket, :form, to_form(Shopping.change_new_entry(), as: :entry))

  defp article_options(recent) do
    recent_names = Enum.map(recent, & &1.article.name)
    recent_set = MapSet.new(recent_names)
    others = for a <- Catalog.list_articles(), a.name not in recent_set, do: a.name

    Enum.reject(
      [
        {"Zuletzt verwendet", Enum.map(recent_names, &{&1, &1})},
        {"Artikel", Enum.map(others, &{&1, &1})}
      ],
      &match?({_group, []}, &1)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current={:lists}>
      <.header back={~p"/"}>
        {@list.name}
        <:subtitle>
          {join_meta([open_text(@open_count), if(@list.shared, do: "Geteilt", else: "Privat")])}
        </:subtitle>
        <:actions :if={@owner?}>
          <.button
            id="list-settings"
            navigate={~p"/lists/#{@list}/settings"}
            variant={:ghost}
            icon="ellipsis-vertical"
            icon_only
            label="Liste bearbeiten"
          />
        </:actions>
      </.header>

      <div class="flex flex-col gap-8">
        <.empty_state :if={@areas == []} id="entries-empty" title="Nichts offen">
          Was ihr braucht, fügst du unten hinzu.
        </.empty_state>

        <div :if={@areas != []} id="open-entries" class="flex flex-col gap-8">
          <section
            :for={[%{article: %{area: area}} | _] = entries <- @areas}
            id={"area-#{area.key}"}
            aria-labelledby={"area-#{area.key}-title"}
          >
            <.section_heading id={"area-#{area.key}-title"} count={length(entries)}>
              {area.name}
            </.section_heading>
            <.list>
              <.entry_row :for={entry <- entries} entry={entry} tap="check_off" tap_label="Abhaken" />
            </.list>
          </section>
        </div>

        <section :if={@recent != []} id="recent-entries" aria-labelledby="recent-entries-title">
          <.section_heading id="recent-entries-title">Zuletzt verwendet</.section_heading>
          <.list>
            <.entry_row
              :for={entry <- @recent}
              entry={entry}
              tap="put_back"
              tap_label="Wieder auf die Liste"
            />
          </.list>
        </section>
      </div>

      <.form for={@form} id="add-entry" phx-change="change_entry" phx-submit="add" class="mt-8">
        <.action_bar sticky>
          <div class="flex w-full items-start gap-2">
            <div class="min-w-0 flex-1">
              <.combobox
                field={@form[:name]}
                label="Artikel"
                hide_label
                options={@article_options}
                allow_create
                create_label="„%{text}“ hinzufügen"
                placeholder="Was brauchst du?"
              />
            </div>
            <div class="w-28 shrink-0">
              <.input
                field={@form[:detail]}
                label="Angabe"
                hide_label
                placeholder="Angabe"
                maxlength="80"
                autocomplete="off"
              />
            </div>
            <.button type="submit" variant={:primary} icon="plus" icon_only label="Hinzufügen" />
          </div>
        </.action_bar>
      </.form>

      <.modal
        id="edit-entry"
        show={@editing != nil}
        title={@editing && edit_title(@edit, @editing.article.name)}
        on_cancel={JS.push("close_edit")}
      >
        <.form
          :if={@edit == :detail}
          for={@edit_form}
          id="edit-detail"
          phx-change="validate_detail"
          phx-submit="save_detail"
        >
          <.input field={@edit_form[:detail]} label="Angabe" maxlength="80" autocomplete="off" />
        </.form>
        <.form :if={@edit == :area} for={@edit_form} id="edit-area" phx-submit="save_area">
          <.input
            field={@edit_form[:area_id]}
            type="radio_group"
            label="Bereich"
            hide_label
            options={@area_options}
            help="Gilt auf allen Listen."
          />
        </.form>
        <:actions>
          <.button phx-click={hide_modal("edit-entry")}>Abbrechen</.button>
          <.button :if={@edit} type="submit" form={"edit-#{@edit}"} variant={:primary}>
            Speichern
          </.button>
        </:actions>
      </.modal>
    </Layouts.app>
    """
  end

  attr :entry, :map, required: true
  attr :tap, :string, required: true
  attr :tap_label, :string, required: true

  defp entry_row(assigns) do
    ~H"""
    <.list_row
      id={"entry-#{@entry.id}"}
      on_click={JS.push(@tap, value: %{id: @entry.id})}
      menu={:always}
      actions_label={"Aktionen: #{@entry.article.name}"}
    >
      <span class="sr-only">{@tap_label}:</span>
      {@entry.article.name}
      <:leading><.article_picture article={@entry.article} /></:leading>
      <:meta :if={@entry.detail}>{@entry.detail}</:meta>
      <:action
        id={"entry-#{@entry.id}-detail"}
        label="Angabe ändern"
        icon="pencil"
        on_click={JS.push("edit_detail", value: %{id: @entry.id})}
      />
      <:action
        id={"entry-#{@entry.id}-area"}
        label="Bereich ändern"
        icon="tag"
        on_click={JS.push("edit_area", value: %{id: @entry.id})}
      />
    </.list_row>
    """
  end

  defp edit_title(:detail, name), do: "Angabe für #{name}"
  defp edit_title(:area, name), do: "Bereich für #{name}"
end
