import { forgetLists, saveLists } from "../offline/store.js"
import { serverReachable } from "../offline/network.js"
import { sync } from "../offline/sync.js"

// A short drop of the socket is not a lost reception; LiveView reconnects by itself.
const GRACE = 3000

// Probes the server every GRACE until stopped and reloads once it is out of reach, so that the
// service worker shows the offline page.
function watch() {
  let watching = true

  const check = async () => {
    if (!watching) return
    if (navigator.serviceWorker?.controller && !(await serverReachable())) {
      if (watching) window.location.reload()
    } else {
      setTimeout(check, GRACE)
    }
  }

  setTimeout(check, GRACE)
  return () => (watching = false)
}

let stopWatchingJoin = () => {}

// A page whose socket never joins mounts no hook, so the first mount ends this watch.
export function watchUntilJoined() {
  if (document.getElementById("offline")) stopWatchingJoin = watch()
}

// On every signed-in page: keeps the offline copy, syncs the queue, and watches the server while
// the socket is down.
export const Offline = {
  mounted() {
    stopWatchingJoin()
    this.handleEvent("offline_copy", ({ lists }) => saveLists(lists).catch(() => {}))
    sync()
  },

  disconnected() {
    this.stopWatching?.()
    this.stopWatching = watch()
  },

  reconnected() {
    this.stopWatching?.()
    sync()
  },

  destroyed() {
    this.stopWatching?.()
  },
}

// On the sign-in pages: the lists of whoever signed out stay off this device.
export const OfflineForget = {
  mounted() {
    forgetLists().catch(() => {})
  },
}
