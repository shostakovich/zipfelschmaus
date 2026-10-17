import Config

# DATABASE_PATH points a preview at a copy of other data.
database =
  System.get_env("DATABASE_PATH") || Path.expand("../storage/development.sqlite3", __DIR__)

config :zipfelschmaus, Zipfelschmaus.Repo,
  database: database,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

config :zipfelschmaus, ZipfelschmausWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "AN7TpCBRQnCYlCvAFx9mmmaI7iliS4QRCiZb4iiwqjdb0x7Fc2nU3VQ6ye6RSmq8",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:zipfelschmaus, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:zipfelschmaus, ~w(--watch)]}
  ]

config :zipfelschmaus, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true
