// The offline page: the start page or a list from the offline copy, in the markup of the page's
// Setzkasten templates. A tap queues the check-off or put-back; once the server answers again
// the page reloads, and the signed-in page that loads syncs the queue.

import { enqueue, listView, pendingCount, pendingText, startView } from "./offline/lists.js"
import { readLists, readQueue, updateQueue } from "./offline/store.js"
import { serverReachable } from "./offline/network.js"

const RECONNECT_INTERVAL = 30000
const LIST_PATH = /^\/lists\/(\d+)$/

const byId = (id) => document.getElementById(id)

async function render() {
  const [lists, queue] = await Promise.all([readLists(), readQueue()])
  const listId = Number(window.location.pathname.match(LIST_PATH)?.[1])
  const list = lists.find((list) => list.id === listId)

  byId("offline-pending").textContent = pendingText(pendingCount(lists, queue))
  byId("offline-start").hidden = Boolean(listId)
  byId("offline-list").hidden = !list
  byId("offline-missing").hidden = !listId || Boolean(list)

  if (list) renderList(listView(list, queue))
  else if (!listId) renderStart(startView(lists, queue))
}

function renderStart({ shared, private: own }) {
  byId("lists-empty").hidden = shared.length + own.length > 0
  renderSection(byId("shared-lists"), shared.map(listRow))
  renderSection(byId("private-lists"), own.map(listRow))
}

function renderList({ name, meta, areas, recent }) {
  const page = byId("offline-list")
  fill(page, "name", name)
  fill(page, "meta", meta)

  byId("entries-empty").hidden = areas.length > 0
  byId("open-entries").replaceChildren(...areas.map(areaSection))
  renderSection(byId("recent-entries"), recent.map(entryRow))
}

function renderSection(section, rows) {
  section.hidden = rows.length === 0
  section.querySelector("ul").replaceChildren(...rows)
}

function listRow({ id, name, initial, meta }) {
  const row = clone("offline-list-row")
  row.id = `list-${id}`
  row.querySelector("a").href = `/lists/${id}`
  fill(row, "name", name)
  fill(row, "meta", meta)
  row.querySelector(".avatar span").textContent = initial
  return row
}

function areaSection({ id, name, entries }) {
  const section = clone("offline-area")
  const heading = section.querySelector("h2")
  section.id = `area-${id}`
  section.setAttribute("aria-labelledby", `area-${id}-title`)
  heading.id = `area-${id}-title`
  heading.lastElementChild.textContent = entries.length
  fill(section, "name", name)
  section.querySelector("ul").replaceChildren(...entries.map(entryRow))
  return section
}

function entryRow({ id, name, detail, initial, checkedOff }) {
  const row = clone("offline-entry")
  row.id = `entry-${id}`
  row.dataset.entryId = id
  row.dataset.checkedOff = checkedOff
  fill(row, "action", checkedOff ? "Wieder auf die Liste:" : "Abhaken:")
  fill(row, "name", name)
  if (detail) fill(row, "detail", detail)
  else row.querySelector("[data-slot=detail]").parentElement.remove()
  row.querySelector(".avatar span").textContent = initial
  return row
}

const clone = (templateId) => byId(templateId).content.firstElementChild.cloneNode(true)

const fill = (element, slot, text) => (element.querySelector(`[data-slot=${slot}]`).textContent = text)

async function toggle(row) {
  const change = {
    entry_id: Number(row.dataset.entryId),
    checked_off: row.dataset.checkedOff !== "true",
    at: new Date().toISOString(),
  }

  await updateQueue((queue) => enqueue(queue, change))
  await render()
}

function followOffline(link, event) {
  const url = new URL(link.href)
  if (url.origin !== window.location.origin) return
  if (url.pathname !== "/" && !LIST_PATH.test(url.pathname)) return

  event.preventDefault()
  window.history.pushState(null, "", url.pathname)
  render().then(() => window.scrollTo(0, 0))
}

document.addEventListener("click", (event) => {
  const row = event.target.closest("[data-entry-id]")
  const link = event.target.closest("a[href]")

  if (row && event.target.closest("button")) toggle(row)
  else if (link) followOffline(link, event)
})

window.addEventListener("popstate", render)

async function reconnect() {
  if (await serverReachable()) window.location.reload()
}

window.addEventListener("online", reconnect)
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") reconnect()
})
setInterval(reconnect, RECONNECT_INTERVAL)

render()
