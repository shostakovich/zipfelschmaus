import Config

alias Zipfelschmaus.{Network, TLS}

if System.get_env("PHX_SERVER") do
  config :zipfelschmaus, ZipfelschmausWeb.Endpoint, server: true
end

read_env? = config_env() != :test

# Trimmed; an empty value counts as unset.
env = fn name ->
  value = if read_env?, do: name |> System.get_env("") |> String.trim(), else: ""
  if value != "", do: value
end

networks! = fn name, default ->
  case Network.parse_list(env.(name) || default) do
    {:ok, networks} -> networks
    {:error, reason} -> raise "invalid #{name}: #{reason}"
  end
end

# The users' secrets come from Release.create_mcp_secret/1, not from the environment.
config :zipfelschmaus, :mcp,
  allowed_cidrs: networks!.("MCP_ALLOWED_CIDRS", "160.79.104.0/21"),
  trusted_proxies: networks!.("TRUSTED_PROXIES", "")

port =
  case Integer.parse(env.("PORT") || "4000") do
    {port, ""} when port in 1..65_535 -> port
    _invalid -> raise "invalid PORT: #{inspect(env.("PORT"))} is not a port number"
  end

# Area guesses by any OpenAI-compatible chat API, e.g. http://ollama:11434/v1; without URL and
# model new articles stay in "Sonstiges".
config :zipfelschmaus, Zipfelschmaus.LanguageModel.ChatAPI,
  url: env.("MODEL_URL"),
  model: env.("MODEL"),
  api_key: env.("MODEL_KEY"),
  thinking: env.("MODEL_THINKING") in ~w(on true 1)

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

  smtp_host = env!.("SMTP_HOST", "smtp.example.com")

  smtp_port =
    case Integer.parse(env.("SMTP_PORT") || "587") do
      {port, ""} when port in 1..65_535 -> port
      _invalid -> raise "invalid SMTP_PORT: #{inspect(env.("SMTP_PORT"))} is not a port number"
    end

  verify_tls = TLS.verify_options(smtp_host)

  # Port 465 speaks TLS from the start, any other port upgrades with STARTTLS.
  config :zipfelschmaus, Zipfelschmaus.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: smtp_host,
    port: smtp_port,
    username: env!.("SMTP_USERNAME", "schmaus@example.org"),
    password: env!.("SMTP_PASSWORD", "secret"),
    auth: :always,
    ssl: smtp_port == 465,
    sockopts: if(smtp_port == 465, do: verify_tls, else: []),
    tls: if(smtp_port == 465, do: :never, else: :always),
    tls_options: verify_tls,
    retries: 1

  config :zipfelschmaus, :mail_from, {"ZipfelSchmaus", env!.("MAIL_FROM", "schmaus@example.org")}
end
