import { beforeEach, describe, mock, test } from "node:test"
import assert from "node:assert/strict"

import { PasskeyLogin, PasskeyRegister } from "../js/hooks/passkey.js"

beforeEach(() => {
  globalThis.window = { PublicKeyCredential: class {} }
  globalThis.document = { querySelector: () => ({ getAttribute: () => "csrf" }) }
})

// Clicks the sign-in button and resolves with the message the hook reports, or null.
function signIn() {
  return new Promise((resolve) => {
    let click
    const hook = {
      ...PasskeyLogin,
      el: { dataset: {}, addEventListener: (_event, listener) => (click = listener) },
      pushEvent: (_event, { message }) => resolve(message),
    }
    hook.mounted()
    click()
    setTimeout(() => resolve(null), 10)
  })
}

describe("a failed passkey sign-in", () => {
  test("shows the server's reason", async () => {
    globalThis.fetch = mock.fn(async () => ({
      ok: false,
      redirected: false,
      json: async () => ({ error: "Unvollständige Anfrage." }),
    }))

    assert.equal(await signIn(), "Unvollständige Anfrage.")
  })

  test("asks to sign in again once the session expired", async () => {
    globalThis.fetch = mock.fn(async () => ({
      ok: true,
      redirected: true,
      json: async () => {
        throw new SyntaxError("Unexpected token '<'")
      },
    }))

    assert.equal(await signIn(), "Bitte melde dich erneut an.")
  })

  test("shows a German text for an error of the browser", async () => {
    globalThis.fetch = mock.fn(async () => {
      throw new TypeError("Failed to fetch")
    })

    assert.equal(await signIn(), "Der Passkey hat nicht geklappt.")
  })

  test("says nothing when the dialog was cancelled", async () => {
    globalThis.fetch = mock.fn(async () => {
      throw new DOMException("The operation was aborted.", "AbortError")
    })

    assert.equal(await signIn(), null)
  })
})

describe("adding a passkey", () => {
  test("asks for a name before the browser creates the passkey", async () => {
    globalThis.fetch = mock.fn(async () => {
      throw new Error("no request expected")
    })

    const message = await new Promise((resolve) => {
      let submit
      const hook = {
        ...PasskeyRegister,
        el: {
          elements: { namedItem: () => ({ value: "  " }) },
          addEventListener: (_event, listener) => (submit = listener),
        },
        pushEvent: (_event, { message }) => resolve(message),
      }
      hook.mounted()
      submit({ preventDefault: () => {} })
    })

    assert.equal(message, "Bitte gib dem Passkey einen Namen.")
    assert.equal(globalThis.fetch.mock.callCount(), 0)
  })
})
