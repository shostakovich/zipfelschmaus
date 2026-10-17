import { afterEach, beforeEach, describe, mock, test } from "node:test"
import assert from "node:assert/strict"

import { Offline, watchUntilJoined } from "../js/hooks/offline.js"

const GRACE = 3000

let reachable
let reload

beforeEach(() => {
  mock.timers.enable({ apis: ["setTimeout"] })
  reachable = true
  reload = mock.fn()
  globalThis.fetch = mock.fn(async () => ({ ok: reachable }))
  globalThis.window = { location: { reload } }
  globalThis.document = { getElementById: (id) => (id === "offline" ? {} : null) }
  Object.defineProperty(globalThis, "navigator", {
    value: { serviceWorker: { controller: {} } },
    configurable: true,
  })
})

afterEach(() => mock.timers.reset())

const settle = () => new Promise((resolve) => setImmediate(resolve))

async function wait() {
  mock.timers.tick(GRACE)
  await settle()
}

const hook = () => ({ handleEvent: () => {} })

describe("a page whose socket never joins", () => {
  test("keeps probing while the server answers and reloads once it does not", async () => {
    watchUntilJoined()

    await wait()
    await wait()
    assert.equal(globalThis.fetch.mock.callCount(), 2)
    assert.equal(reload.mock.callCount(), 0)

    reachable = false
    await wait()
    assert.equal(reload.mock.callCount(), 1)
  })

  test("stops probing once the hook mounts", async () => {
    watchUntilJoined()
    Offline.mounted.call(hook())
    reachable = false

    await wait()
    assert.equal(reload.mock.callCount(), 0)
  })
})

describe("a mounted page that loses its socket", () => {
  test("keeps probing while the server answers and reloads once it does not", async () => {
    const offline = hook()
    Offline.disconnected.call(offline)

    await wait()
    await wait()
    assert.equal(reload.mock.callCount(), 0)

    reachable = false
    await wait()
    assert.equal(reload.mock.callCount(), 1)
  })

  test("stops probing once the socket is back", async () => {
    const offline = hook()
    Offline.disconnected.call(offline)
    Offline.reconnected.call(offline)
    reachable = false

    await wait()
    assert.equal(reload.mock.callCount(), 0)
  })

  test("does not reload without a service worker to show the offline page", async () => {
    Object.defineProperty(globalThis, "navigator", { value: {}, configurable: true })
    Offline.disconnected.call(hook())
    reachable = false

    await wait()
    assert.equal(reload.mock.callCount(), 0)
  })
})
