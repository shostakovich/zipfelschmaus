// PwaController puts SHELL in front, the offline page and the files it loads, and VERSION, a hash
// of the offline page's templates; a change to either installs the worker anew.
// Pages always come from the network; the shell only stands in when it does not answer.

const CACHE = "shell"
const OFFLINE_PAGE = "/offline"
// A phone without reception often hangs instead of failing.
const NETWORK_TIMEOUT = 5000
const GATEWAY_ERRORS = [502, 503, 504]

const SHELL_URLS = new Set(SHELL.map((path) => new URL(path, self.location.origin).href))

self.addEventListener("install", (event) =>
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting()),
  ),
)

self.addEventListener("activate", (event) =>
  event.waitUntil(forgetOldShell().then(() => self.clients.claim())),
)

async function forgetOldShell() {
  const cache = await caches.open(CACHE)
  const requests = await cache.keys()
  await Promise.all(
    requests.filter((request) => !SHELL_URLS.has(request.url)).map((request) => cache.delete(request)),
  )
}

self.addEventListener("fetch", (event) => {
  const { request } = event

  if (request.mode === "navigate") event.respondWith(page(request))
  else if (request.method === "GET" && SHELL_URLS.has(request.url)) event.respondWith(shellFile(request))
})

async function page(request) {
  try {
    const response = await fromNetwork(request)
    if (!GATEWAY_ERRORS.includes(response.status)) return response
  } catch {}

  return (await caches.match(OFFLINE_PAGE)) || notice()
}

// A digested file never changes, so only the others need the network first.
async function shellFile(request) {
  const cached = new URL(request.url).searchParams.has("vsn") && (await caches.match(request))
  if (cached) return cached

  try {
    const response = await fromNetwork(request)
    if (response.ok) await (await caches.open(CACHE)).put(request, response.clone())
    return response
  } catch {
    return (await caches.match(request)) || Response.error()
  }
}

function fromNetwork(request) {
  return Promise.race([
    fetch(request),
    new Promise((_resolve, reject) => setTimeout(reject, NETWORK_TIMEOUT)),
  ])
}

const STYLE =
  "body{font-family:system-ui,sans-serif;margin:0;min-height:100vh;display:flex;" +
  "align-items:center;justify-content:center;padding:1rem;text-align:center;" +
  "color:#0d1928;background:#fff}a{color:inherit}" +
  "@media(prefers-color-scheme:dark){body{color:#e9ebef;background:#202328}}"

const OFFLINE =
  '<!doctype html><html lang="de"><head><meta charset="utf-8">' +
  '<meta name="viewport" content="width=device-width, initial-scale=1">' +
  `<title>Offline</title><style>${STYLE}</style></head><body><main>` +
  "<h1>Keine Verbindung</h1><p>Der Server ist gerade nicht erreichbar.</p>" +
  '<p><a href="">Erneut versuchen</a></p></main></body></html>'

let policy

// The notice keeps a strict policy: its one inline style is allowed by its hash.
async function offlinePolicy() {
  if (!policy) {
    const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(STYLE))
    const hash = btoa(String.fromCharCode(...new Uint8Array(digest)))
    policy = `default-src 'none'; style-src 'sha256-${hash}'; base-uri 'none'; form-action 'none'`
  }
  return policy
}

// Only until the shell is cached, e.g. when the first visit lost its connection.
async function notice() {
  return new Response(OFFLINE, {
    status: 503,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Content-Security-Policy": await offlinePolicy(),
    },
  })
}
