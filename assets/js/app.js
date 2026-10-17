import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/zipfelschmaus"
import { hooks as setzkastenHooks } from "phoenix-colocated/setzkasten"

import { Offline, OfflineForget, watchUntilJoined } from "./hooks/offline.js"
import { PasskeyLogin, PasskeyRegister } from "./hooks/passkey.js"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: {
    ...colocatedHooks,
    ...setzkastenHooks,
    Offline,
    OfflineForget,
    PasskeyLogin,
    PasskeyRegister,
  },
})

watchUntilJoined()
liveSocket.connect()
window.liveSocket = liveSocket

if ("serviceWorker" in navigator && window.isSecureContext) {
  window.addEventListener("load", () => navigator.serviceWorker.register("/sw.js").catch(() => {}))
}
