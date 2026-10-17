# ZipfelSchmaus

Shopping lists, recipes and the pantry for a two-person household. **The user interface is German.**

## Before you use this

- A personal project, built for my own household.
- No pull requests, but forks are welcome.

## Development

- Erlang and Elixir as in `.tool-versions`
- `mix setup` (deps, database in `storage/`, assets), then `mix phx.server` (http://localhost:4000)
- `mix zipfelschmaus.create_user EMAIL` creates a user; there is no sign-up. Sign-in links land in the
  mailbox at http://localhost:4000/dev/mailbox.
- `mix zipfelschmaus.create_mcp_secret EMAIL` gives a user an MCP endpoint; call it from localhost with
  `MCP_ALLOWED_CIDRS=127.0.0.1/32` (see [MCP](#mcp)).
- Checks, as CI runs them: `mix format --check-formatted`, `mix compile --warnings-as-errors`,
  `mix credo --strict`, `mix test --warnings-as-errors`, `node --test assets/test/*.test.js` (Node.js 22,
  no packages), `mix assets.setup && mix assets.deploy`

## Running it

- Image `ghcr.io/shostakovich/zipfelschmaus` (linux/amd64): `latest` follows `main`, every pushed image is also
  tagged `sha-<commit>`; pull requests are only built and smoke-tested.
- [compose.yaml](compose.yaml) is an example; put the app behind a reverse proxy that terminates TLS.
- The container runs as uid 1000; the data volume `/app/data` must be writable for it.
- Migrations run on start. The health check calls `/up`.
- Users sign in with a passkey or a sign-in link by mail. Create each one with
  `docker compose exec zipfelschmaus bin/zipfelschmaus eval 'Zipfelschmaus.Release.create_user("anna@example.org")'`;
  the sign-in page then sends them a link. Passkeys are bound to `PHX_HOST`, so sign in through that name.
- Environment: `SECRET_KEY_BASE` (required, e.g. `openssl rand -hex 64`), `PHX_HOST` (required, the public host
  name), `SMTP_HOST`, `SMTP_USERNAME`, `SMTP_PASSWORD` and `MAIL_FROM` (required, for sign-in links), `SMTP_PORT`
  (default `587` with STARTTLS; `465` speaks TLS from the start), `DATABASE_PATH` (default
  `/app/data/zipfelschmaus.sqlite3`), `PORT` (default `4000`), `TZ` (default `Europe/Berlin`).
- The area of a new article is guessed by any OpenAI-compatible chat API, such as Ollama or LM Studio:
  `MODEL_URL` (e.g. `http://ollama:11434/v1`), `MODEL` (the model's name), `MODEL_KEY` (optional) and
  `MODEL_THINKING` (`on` lets a thinking model think). Without URL and model, new articles stay in
  "Sonstiges".
- MCP: `MCP_ALLOWED_CIDRS` (default `160.79.104.0/21`, Anthropic) and `TRUSTED_PROXIES` (default none), see
  [MCP](#mcp).

## MCP

Claude reads and edits the lists through a stateless MCP endpoint (protocol version `2026-07-28` only), acting as
one user: it sees that user's own lists and the shared ones, never the other user's private lists.

- Each user has their own secret; the endpoint is `POST https://<PHX_HOST>/mcp/<secret>`. Create one with
  `docker compose exec zipfelschmaus bin/zipfelschmaus eval 'Zipfelschmaus.Release.create_mcp_secret("anna@example.org")'`;
  it prints the path once. Running it again replaces the secret, so the old connector stops working. Only a hash
  of the secret is stored. A user without a secret has no endpoint.
- Connect it in Claude as a custom connector with the URL `https://<PHX_HOST>/mcp/<secret>`, without
  authentication. If the reverse proxy puts a login in front of the app, exclude `/mcp/` from it.
- Tools: `list_lists`, `read_list`, `list_areas`, `add_entries` (by article name, with detail and, for a new
  article, an area), `check_off`, `put_back`, `create_list`, `set_article_area` (counts as set by hand). Nothing
  is deleted.
- Checked in this order: the secret (an unknown one is a plain `404`), `POST` only (`405`), the client address in
  `MCP_ALLOWED_CIDRS` (`403`), no `Origin` header, so no browser (`403`), `Content-Type: application/json`
  (`415`), at most 1 MiB (`413`).
- The client address is the TCP peer; only when the peer is in `TRUSTED_PROXIES` does `X-Forwarded-For` count,
  read from the right (without it, `X-Real-IP`). Put exactly the proxy's own address there. A refused call logs
  the addresses it saw; the path with the secret is never logged.
- The proxy must overwrite or append `X-Forwarded-For`, or a client could write its own address there; in
  nginx: `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`.

## Stack

- Phoenix 1.8 with LiveView, SQLite via ecto_sqlite3
- [Setzkasten](https://github.com/shostakovich/setzkasten) on Tailwind CSS 4 and daisyUI 5

## License

Public domain ([The Unlicense](LICENSE)).
