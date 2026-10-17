import Config

config :zipfelschmaus, ZipfelschmausWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :zipfelschmaus, forwarded_ssl: true

config :logger, level: :info
