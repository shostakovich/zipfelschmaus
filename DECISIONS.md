# Decisions

## 0001. Phoenix, LiveView and SQLite in one container

Accepted, 2026-10-17

- **Context:** A two-person household app, self-hosted on one server next to sibling apps built the same way.
- **Decision:** One Phoenix release with LiveView and SQLite, jobs in-process, a single instance.
- **Consequences:** One writer at a time and no horizontal scaling; moving to Postgres later means a data migration.

## 0002. The UI is built on Setzkasten

Accepted, 2026-10-17

- **Context:** All of the author's Phoenix apps share one component library and theme.
- **Decision:** Pages use Setzkasten components; a gap or bug is fixed in Setzkasten, not worked around in the app.
- **Consequences:** Some features wait for a Setzkasten change; the apps stay consistent.

## 0003. A PWA with offline check-off instead of a native app

Accepted, 2026-10-17

- **Context:** The supermarket has no mobile reception, so lists must work offline; the rest of the app is fine online.
- **Decision:** An installable PWA: a service worker caches the shopping view, open lists live in IndexedDB, and check-offs queue until the next connection, the latest change per entry winning. Adding and editing need a connection. A native iOS app was rejected as a second codebase for one offline feature.
- **Consequences:** A small hand-written JS layer beside LiveView; iOS suspends the PWA in the background, so no timers or local notifications.

## 0004. Passkey login

Accepted, 2026-10-17

- **Context:** The app is reachable from outside the home network and holds private lists.
- **Decision:** Passkeys with an email sign-in link as fallback, as in zipfelfolio; users are created by a mix task, there is no sign-up.
- **Consequences:** Sign-in needs the real domain, not the LAN IP; mail delivery must work for recovery.

## 0005. A shared article catalog is the backbone

Accepted, 2026-10-17

- **Context:** Shopping lists, recipe ingredients and the pantry all talk about the same things (milk, chickpeas).
- **Decision:** One catalog of articles, each with an area, a picture and barcodes; list entries, ingredients and pantry items point to articles instead of holding free text.
- **Consequences:** Free-text input must be matched to an article or create one; merging duplicate articles later touches all three parts.

## 0006. A stateless MCP server behind a secret path

Superseded by 0009, 2026-10-17

- **Context:** Lists and recipes are edited from Claude; the connector cannot do the passkey login.
- **Decision:** A hand-written, stateless JSON-RPC endpoint at `/mcp/<secret>` with an address filter, as in Zipfelkasse.
- **Consequences:** Whoever knows the secret from an allowed network has full access; rotating it means updating every connector.

## 0007. A local model guesses areas and parses ingredients

Accepted, 2026-10-17

- **Context:** New articles need an area for sorting, and imported recipe lines need amount, unit and article for scaling.
- **Decision:** A self-hosted model behind an OpenAI-compatible API, the same one zipfelfolio uses so it is not reloaded; results land asynchronously and a manual correction always wins.
- **Consequences:** Guesses take seconds and can be wrong; the app must work while the model is busy or down.

## 0008. The pantry is an expiry watch with FIFO and target stock

Accepted, 2026-10-17

- **Context:** Food in the pantry goes bad unnoticed, and a rough emergency supply is wanted, without micro-managing every can.
- **Decision:** Items are article, best-before month and count; taking one out by scan removes it from the earliest date. Items due within four weeks ask for a check, which also corrects the count. Each article may have a target stock, seeded from the federal emergency checklist; below it, one tap puts it on a list.
- **Consequences:** Counts drift when nobody scans; the due check is the only correction, so dates must be entered.

## 0009. One MCP secret per user

Accepted, 2026-10-17

- **Context:** ADR 0006 gave the MCP endpoint one secret with full access, but private lists must stay hidden from the other person, also through Claude.
- **Decision:** Each user gets their own secret at `/mcp/<secret>`, stored only as its hash in `users_tokens`; a connector acts as that user and sees their own and the shared lists. The stateless endpoint and the address filter stay as in 0006.
- **Consequences:** Whoever knows a secret has that user's access; rotating one leaves the other user's connector working, and each user sets up their own connector.
