# ZipfelSchmaus

Shopping lists, recipes and the pantry for a two-person household. **The user interface is German.**

## Before you use this

- A personal project, built for my own household.
- No pull requests, but forks are welcome.

## Development

- Erlang and Elixir as in `.tool-versions`
- `mix setup` (deps, database in `storage/`, assets), then `mix phx.server` (http://localhost:4000)
- Checks, as CI runs them: `mix format --check-formatted`, `mix compile --warnings-as-errors`,
  `mix credo --strict`, `mix test --warnings-as-errors`, `mix assets.setup && mix assets.deploy`

## Running it

- Image `ghcr.io/shostakovich/zipfelschmaus` (linux/amd64): `latest` follows `main`, every pushed image is also
  tagged `sha-<commit>`; pull requests are only built and smoke-tested.
- [compose.yaml](compose.yaml) is an example; put the app behind a reverse proxy that terminates TLS.
- The container runs as uid 1000; the data volume `/app/data` must be writable for it.
- Migrations run on start. The health check calls `/up`.
- Environment: `SECRET_KEY_BASE` (required, e.g. `openssl rand -hex 64`), `PHX_HOST` (required, the public host
  name), `DATABASE_PATH` (default `/app/data/zipfelschmaus.sqlite3`), `PORT` (default `4000`), `TZ` (default
  `Europe/Berlin`).

## Stack

- Phoenix 1.8 with LiveView, SQLite via ecto_sqlite3
- [Setzkasten](https://github.com/shostakovich/setzkasten) on Tailwind CSS 4 and daisyUI 5

## License

Public domain ([The Unlicense](LICENSE)).
