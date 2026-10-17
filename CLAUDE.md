# CLAUDE.md – ZipfelSchmaus

## Stack

- Phoenix 1.8 with LiveView 1.2 on SQLite (ecto_sqlite3), served by Bandit; one container
- UI: [Setzkasten](https://github.com/shostakovich/setzkasten) components on Tailwind CSS 4 and daisyUI 5
- Erlang/Elixir versions: `.tool-versions`

## Commands

- `mix setup`, then `mix phx.server` (http://localhost:4000)
- Checks, as CI runs them:
  - `mix format --check-formatted`
  - `mix compile --warnings-as-errors`
  - `mix credo --strict`
  - `mix test --warnings-as-errors`
  - `mix assets.setup && mix assets.deploy`

## Conventions

- UI text is German; code, comments, commits and docs are English. Comments are rare: only a
  non-obvious why.
- Schemas `use Zipfelschmaus.Schema` (`:utc_datetime_usec` timestamps). Migrations are recorded in
  production: add new ones, leave old ones as they are; releases run them via `Release.migrate/0`.
- UI: Setzkasten components via `use Setzkasten`; app-specific styles only in `assets/css/app.css`.
  A gap or bug in Setzkasten is fixed in Setzkasten, not worked around in the app.
- Pages assign their whole title with `Layouts.page_title/1`.
- The strict CSP allows no inline scripts or styles; an inline script carries `@csp_nonce`.
- Tests are London-style: outside-in, each unit tested with its collaborators replaced by test
  doubles at their boundary. DB tests run synchronously with `pool_size: 1` (SQLite allows one
  writer).
- Dependencies: few and mature, each with a reason.
