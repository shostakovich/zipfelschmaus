defmodule ZipfelschmausWeb.Layouts do
  @moduledoc false
  use ZipfelschmausWeb, :html

  embed_templates "layouts/*"

  @app_name "ZipfelSchmaus"

  @doc "The app's name, as the manifest and the page titles show it."
  def app_name, do: @app_name

  attr :flash, :map, required: true
  attr :current, :atom, default: nil, doc: "the open section"

  slot :inner_block, required: true

  @doc "Pages in Setzkasten's top-bar shell."
  def app(assigns) do
    ~H"""
    <.app_shell layout={:topbar} width={:narrow} current={@current}>
      <:brand>
        <.link navigate={~p"/"} class="flex min-w-0 items-center gap-2">
          <.plush src={~p"/images/icons/icon-192.webp"} size={:lg} class="rounded-lg" />
          <span class="truncate">{app_name()}</span>
        </.link>
      </:brand>
      {render_slot(@inner_block)}
    </.app_shell>

    <.flash_group flash={@flash} />
    <.confirm_dialog />
    """
  end

  @doc "A page's title with the app's name; pages assign it whole as `page_title`."
  def page_title(page), do: page <> " · " <> @app_name
end
