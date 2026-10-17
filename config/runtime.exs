import Config

if System.get_env("PHX_SERVER") do
  config :zipfelschmaus, ZipfelschmausWeb.Endpoint, server: true
end

read_env? = config_env() != :test

# Trimmed; an empty value counts as unset.
env = fn name ->
  value = if read_env?, do: name |> System.get_env("") |> String.trim(), else: ""
  if value != "", do: value
end

port =
  case Integer.parse(env.("PORT") || "4000") do
    {port, ""} when port in 1..65_535 -> port
    _invalid -> raise "invalid PORT: #{inspect(env.("PORT"))} is not a port number"
  end

if config_env() == :dev do
  config :zipfelschmaus, ZipfelschmausWeb.Endpoint, http: [port: port], url: [port: port]
end

if config_env() == :prod do
  env! = fn name, example ->
    env.(name) || raise "environment variable #{name} is missing, e.g. #{example}"
  end

  config :zipfelschmaus, Zipfelschmaus.Repo,
    database: env!.("DATABASE_PATH", "/app/data/zipfelschmaus.sqlite3")

  host = env!.("PHX_HOST", "schmaus.example.org")

  # The origin check runs before ForwardedSSL, so it cannot compare schemes behind the proxy.
  config :zipfelschmaus, ZipfelschmausWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    check_origin: ["//" <> host],
    secret_key_base: env!.("SECRET_KEY_BASE", "the output of `openssl rand -hex 64`")
end
