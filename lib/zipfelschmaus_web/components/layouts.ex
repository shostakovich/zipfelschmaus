defmodule ZipfelschmausWeb.Layouts do
  @moduledoc false
  use ZipfelschmausWeb, :html

  embed_templates "layouts/*"

  @app_name "ZipfelSchmaus"

  @doc "The app's name, as the manifest and the page titles show it."
  def app_name, do: @app_name

  attr :flash, :map, required: true
  attr :current, :atom, default: nil, doc: "the open section: `:lists` or `:me`"

  slot :inner_block, required: true

  @doc "Signed-in pages in Setzkasten's shell: the dock on phones, the sidebar from tablets."
  def app(assigns) do
    ~H"""
    <.app_shell layout={:sidebar} width={:narrow} current={@current}>
      <:brand>
        <.link navigate={~p"/"} class="flex min-w-0 items-center gap-2"><.brand /></.link>
      </:brand>
      <:nav key={:lists} label="Listen" icon="list" navigate={~p"/"} />
      <:nav key={:me} label="Ich" icon="user-round" navigate={~p"/me"} />
      {render_slot(@inner_block)}
    </.app_shell>

    <.flash_group flash={@flash} />
    <.confirm_dialog />
    """
  end

  attr :flash, :map, required: true
  slot :inner_block, required: true

  @doc "Sign-in pages: a narrow column without navigation."
  def auth(assigns) do
    ~H"""
    <main id="main" class="mx-auto max-w-md px-4 py-12">
      <h1 class="mb-6 flex items-center justify-center gap-2 text-2xl font-semibold">
        <.brand />
      </h1>
      {render_slot(@inner_block)}
    </main>
    <.flash_group flash={@flash} />
    """
  end

  defp brand(assigns) do
    ~H"""
    <.plush src={~p"/images/icons/icon-192.webp"} size={:lg} class="rounded-lg" />
    <span class="truncate">{app_name()}</span>
    """
  end

  @doc "A page's title with the app's name; pages assign it whole as `page_title`."
  def page_title(page), do: page <> " · " <> @app_name
end
