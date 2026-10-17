import { acknowledge } from "./lists.js"
import { readQueue, updateQueue } from "./store.js"

// 422: the server can never apply the queue, so keeping it would only block the next ones.
const SETTLED = [204, 422]
const TIMEOUT = 10000

let running

export function sync() {
  running ??= send()
    .catch(() => {})
    .finally(() => (running = undefined))
  return running
}

async function send() {
  const queue = await readQueue()
  if (queue.length === 0) return

  const response = await fetch("/sync", {
    method: "POST",
    headers: { "content-type": "application/json", "x-csrf-token": csrfToken() },
    body: JSON.stringify({ changes: queue }),
    signal: AbortSignal.timeout(TIMEOUT),
  })

  if (SETTLED.includes(response.status)) await updateQueue((current) => acknowledge(current, queue))
}

const csrfToken = () => document.querySelector("meta[name='csrf-token']").getAttribute("content")
