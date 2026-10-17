// The lists offline: the copy from the server with the queued check-offs and put-backs on top,
// merged as the server will merge them (Shopping.sync_check_states/2). No DOM, no storage.

const RECENT_LIMIT = 30
const META_SEPARATOR = "⁠ · "
const collator = new Intl.Collator("de")

export function enqueue(queue, change) {
  return [...queue.filter((queued) => queued.entry_id !== change.entry_id), change]
}

export function acknowledge(queue, sent) {
  return queue.filter((queued) => !sent.some((change) => sameChange(change, queued)))
}

const sameChange = (a, b) =>
  a.entry_id === b.entry_id && a.checked_off === b.checked_off && a.at === b.at

// Only the changes that still change an entry of the copy, not one checked off and put back.
export function pendingCount(lists, queue) {
  const entries = new Map(lists.flatMap((list) => list.entries).map((entry) => [entry.id, entry]))

  return queue.filter((change) => {
    const entry = entries.get(change.entry_id)
    return entry !== undefined && applyChange(entry, change) !== entry
  }).length
}

export function pendingText(count) {
  if (count === 0) return "Keine Änderung wartet auf den Abgleich."
  if (count === 1) return "1 Änderung wartet auf den Abgleich."
  return `${count} Änderungen warten auf den Abgleich.`
}

export function startView(lists, queue) {
  const summary = (list) => ({
    id: list.id,
    name: list.name,
    initial: initial(list.name),
    meta: openText(openEntries(merge(list, queue)).length),
  })

  return {
    shared: lists.filter((list) => list.shared).map(summary),
    private: lists.filter((list) => !list.shared).map(summary),
  }
}

export function listView(list, queue) {
  const entries = merge(list, queue)
  const open = openEntries(entries)
  const areaNames = new Map(list.areas.map((area) => [area.id, area.name]))
  const row = (entry) => ({
    id: entry.id,
    name: entry.name,
    detail: entry.detail,
    initial: initial(areaNames.get(entry.area_id) ?? ""),
    checkedOff: entry.checked_off_at !== null,
  })

  const areas = list.areas
    .map((area) => ({
      id: area.id,
      name: area.name,
      entries: open
        .filter((entry) => entry.area_id === area.id)
        .sort((a, b) => collator.compare(a.name, b.name))
        .map(row),
    }))
    .filter((area) => area.entries.length > 0)

  const recent = entries
    .filter((entry) => entry.checked_off_at !== null)
    .sort((a, b) => time(b.checked_off_at) - time(a.checked_off_at))
    .slice(0, RECENT_LIMIT)
    .map(row)

  const meta = [openText(open.length), list.shared ? "Geteilt" : "Privat"].join(META_SEPARATOR)
  return { name: list.name, meta, areas, recent }
}

function merge(list, queue) {
  const changes = new Map(queue.map((change) => [change.entry_id, change]))
  return list.entries.map((entry) => applyChange(entry, changes.get(entry.id)))
}

function applyChange(entry, change) {
  if (!change || time(change.at) <= time(entry.check_changed_at)) return entry
  if ((entry.checked_off_at !== null) === change.checked_off) return entry

  return {
    ...entry,
    checked_off_at: change.checked_off ? change.at : null,
    check_changed_at: change.at,
  }
}

const openEntries = (entries) => entries.filter((entry) => entry.checked_off_at === null)

const openText = (count) => (count === 0 ? "Nichts offen" : `${count} offen`)

const initial = (name) => Array.from(name)[0] ?? ""

const time = (iso) => Date.parse(iso)
