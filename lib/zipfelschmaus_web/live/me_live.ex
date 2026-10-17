defmodule ZipfelschmausWeb.MeLive do
  @moduledoc """
  "Ich": the user's passkeys, the theme and signing out. Adding or deleting a passkey needs a
  recent sign-in, so a session left open on a device cannot take over the account.
  """
  use ZipfelschmausWeb, :live_view

  alias Zipfelschmaus.LocalTime
  alias Zipfelschmaus.Users

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current={:me}>
      <.header>
        Ich
        <:subtitle><span class="wrap-anywhere">{@current_scope.user.email}</span></:subtitle>
        <:actions>
          <.button id="log-out" href={~p"/users/log-out"} method="delete" icon="log-out">
            Abmelden
          </.button>
        </:actions>
      </.header>

      <div class="flex flex-col gap-8">
        <section id="passkeys" aria-labelledby="passkeys-title">
          <.section_heading id="passkeys-title" count={length(@passkeys)}>Passkeys</.section_heading>
          <p class="mb-3 max-w-prose text-sm text-base-content/70">
            Mit einem Passkey meldest du dich per Face ID, Fingerabdruck oder Geräte-PIN an.
          </p>
          <.empty_state :if={@passkeys == []} icon="key-round">
            Noch kein Passkey hinterlegt.
          </.empty_state>
          <.list :if={@passkeys != []}>
            <.list_row :for={passkey <- @passkeys} id={"passkey-#{passkey.id}"} title={passkey.name}>
              <:leading><.icon name="key-round" class="size-5 text-base-content/70" /></:leading>
              <:meta>
                angelegt {date(passkey.inserted_at)}<span :if={passkey.last_used_at}><.meta_sep />zuletzt genutzt {date(
                  passkey.last_used_at
                )}</span>
              </:meta>
              <:action
                :if={@sudo?}
                id={"passkey-#{passkey.id}-delete"}
                label="Löschen"
                icon="trash-2"
                danger
                confirm={"Passkey „#{passkey.name}“ löschen?"}
                on_click={JS.push("delete_passkey", value: %{id: to_string(passkey.id)})}
              />
            </.list_row>
          </.list>
          <form :if={@sudo?} id="passkey-register" class="mt-4" phx-hook="PasskeyRegister">
            <.input
              id="passkey-name"
              name="name"
              label="Name des neuen Passkeys"
              inline
              placeholder="Name, z. B. iPhone"
              maxlength="60"
              required
            >
              <.button type="submit" variant={:primary} icon="plus" class="join-item">
                Passkey hinzufügen
              </.button>
            </.input>
          </form>
          <div :if={!@sudo?} id="passkeys-reauth" class="mt-4">
            <p class="mb-3 max-w-prose text-sm text-base-content/70">
              Um Passkeys hinzuzufügen oder zu löschen, melde dich bitte noch einmal an.
            </p>
            <.button navigate={~p"/users/log-in"} icon="key-round">Erneut anmelden</.button>
          </div>
        </section>

        <section id="theme" aria-labelledby="theme-title">
          <.section_heading id="theme-title">Farbschema</.section_heading>
          <.theme_toggle />
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, Layouts.page_title("Ich"))
     |> assign(:sudo?, sudo?(socket))
     |> assign_passkeys()}
  end

  @impl true
  def handle_event("passkey_registered", _params, socket) do
    {:noreply, socket |> put_flash(:info, "Passkey hinzugefügt.") |> assign_passkeys()}
  end

  def handle_event("passkey_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("delete_passkey", %{"id" => id}, socket) do
    if sudo?(socket) do
      delete_passkey(socket, id)
    else
      {:noreply,
       socket
       |> assign(:sudo?, false)
       |> put_flash(:error, "Bitte melde dich für diese Änderung noch einmal an.")}
    end
  end

  defp delete_passkey(socket, id) do
    case Users.delete_passkey(socket.assigns.current_scope.user, id) do
      {:ok, _passkey} ->
        {:noreply, socket |> put_flash(:info, "Passkey gelöscht.") |> assign_passkeys()}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Den Passkey gibt es nicht mehr.")}
    end
  end

  defp sudo?(socket), do: Users.sudo_mode?(socket.assigns.current_scope.user)

  defp assign_passkeys(socket),
    do: assign(socket, :passkeys, Users.list_passkeys(socket.assigns.current_scope.user))

  defp date(utc), do: utc |> LocalTime.from_utc() |> Format.date()
end
