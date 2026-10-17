// Binary values travel as unpadded base64url, by hand: Safari got
// PublicKeyCredential.parseCreationOptionsFromJSON() only recently.
const toBytes = (text) => {
  const base64 = text.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(text.length / 4) * 4, "=")
  return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0)).buffer
}

const toText = (buffer) =>
  btoa(String.fromCharCode(...new Uint8Array(buffer)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "")

// An error whose message is German and meant for the user.
class Notice extends Error {}

const postJSON = async (url, body) => {
  const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json", "x-csrf-token": csrfToken },
    body: JSON.stringify(body),
  })
  if (response.redirected) throw new Notice("Bitte melde dich erneut an.")
  const data = await response.json().catch(() => ({}))
  if (!response.ok) throw new Notice(data.error || "Der Server hat die Anfrage abgelehnt.")
  return data
}

const supported = () => window.PublicKeyCredential !== undefined

// Cancelling the browser dialog is no error worth a message.
const report = (hook, error) => {
  if (error.name === "NotAllowedError" || error.name === "AbortError") return
  const message = error instanceof Notice ? error.message : "Der Passkey hat nicht geklappt."
  hook.pushEvent("passkey_error", { message })
}

// Posts the assertion through the form named in data-form, so the server answers with a redirect.
export const PasskeyLogin = {
  mounted() {
    if (!supported()) this.el.disabled = true
    this.el.addEventListener("click", () => this.signIn().catch((error) => report(this, error)))
  },

  async signIn() {
    const options = await postJSON("/users/passkeys/options", {})
    const credential = await navigator.credentials.get({
      publicKey: { ...options, challenge: toBytes(options.challenge) },
    })
    const response = credential.response
    const form = document.getElementById(this.el.dataset.form)
    const fields = {
      id: toText(credential.rawId),
      clientDataJSON: toText(response.clientDataJSON),
      authenticatorData: toText(response.authenticatorData),
      signature: toText(response.signature),
      userHandle: response.userHandle ? toText(response.userHandle) : "",
    }

    for (const [name, value] of Object.entries(fields)) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = `passkey[${name}]`
      input.value = value
      form.appendChild(input)
    }
    form.submit()
  },
}

export const PasskeyRegister = {
  mounted() {
    if (!supported()) this.el.querySelector("button").disabled = true
    this.el.addEventListener("submit", (event) => {
      event.preventDefault()
      this.register().catch((error) => report(this, error))
    })
  },

  async register() {
    const name = this.el.elements.namedItem("name").value
    if (name.trim() === "") throw new Notice("Bitte gib dem Passkey einen Namen.")

    const options = await postJSON("/me/passkeys/options", {})
    const credential = await navigator.credentials.create({
      publicKey: {
        ...options,
        challenge: toBytes(options.challenge),
        user: { ...options.user, id: toBytes(options.user.id) },
        excludeCredentials: options.excludeCredentials.map((c) => ({ ...c, id: toBytes(c.id) })),
      },
    })
    const response = credential.response
    const publicKey = response.getPublicKey()
    if (!publicKey) throw new Notice("Dieser Passkey nutzt ein Verfahren, das der Browser nicht ausliefert.")

    await postJSON("/me/passkeys", {
      name,
      passkey: {
        id: toText(credential.rawId),
        clientDataJSON: toText(response.clientDataJSON),
        authenticatorData: toText(response.getAuthenticatorData()),
        publicKey: toText(publicKey),
        publicKeyAlgorithm: response.getPublicKeyAlgorithm(),
      },
    })
    this.el.reset()
    this.pushEvent("passkey_registered", {})
  },
}
