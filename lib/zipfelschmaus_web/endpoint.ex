defmodule ZipfelschmausWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :zipfelschmaus

  alias Plug.Conn.WrapperError

  @session_options [
    store: :cookie,
    key: "_zipfelschmaus_key",
    signing_salt: "c/yQwPpaqlY=",
    same_site: "Lax"
  ]

  if Application.compile_env(:zipfelschmaus, :forwarded_ssl, false) do
    plug ZipfelschmausWeb.ForwardedSSL
  end

  # Before all but the socket transports, so error pages and static files get it too.
  plug ZipfelschmausWeb.ContentSecurityPolicy

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  @fonts Plug.Static.init(
           at: "/setzkasten",
           from: {:setzkasten, "priv/static"},
           only: ~w(fonts),
           cache_control_for_etags: "public, max-age=86400"
         )

  @static Plug.Static.init(
            at: "/",
            from: :zipfelschmaus,
            gzip: not code_reloading?,
            only: ZipfelschmausWeb.static_paths(),
            raise_on_missing_only: code_reloading?
          )

  plug :serve_fonts
  plug :serve_static

  if code_reloading? do
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :zipfelschmaus
  end

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: {__MODULE__, :log_level, []}

  @parsers Plug.Parsers.init(
             parsers: [:urlencoded, :json],
             pass: ["*/*"],
             json_decoder: Phoenix.json_library()
           )

  plug :parse_body

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ZipfelschmausWeb.Router

  @doc false
  # Health checks poll /up and would flood the log.
  def log_level(%Plug.Conn{path_info: ["up"]}), do: false
  def log_level(_conn), do: :info

  # Wrapped like the router's errors, so an error page keeps the headers set above.
  defp serve_fonts(conn, _opts), do: keep_headers_on_error(conn, Plug.Static, @fonts)
  defp serve_static(conn, _opts), do: keep_headers_on_error(conn, Plug.Static, @static)
  defp parse_body(conn, _opts), do: keep_headers_on_error(conn, Plug.Parsers, @parsers)

  defp keep_headers_on_error(conn, plug, opts) do
    plug.call(conn, opts)
  rescue
    error -> WrapperError.reraise(conn, :error, error, __STACKTRACE__)
  end
end
