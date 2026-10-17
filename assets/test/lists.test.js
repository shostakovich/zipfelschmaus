import { describe, test } from "node:test"
import assert from "node:assert/strict"

import { acknowledge, enqueue, listView, pendingCount, pendingText, startView } from "../js/offline/lists.js"

const areas = [
  { id: 1, name: "Obst und Gemüse" },
  { id: 3, name: "Kühlregal" },
  { id: 7, name: "Drogerie" },
]

const entry = (id, name, area_id, changes = {}) => ({
  id,
  name,
  detail: null,
  area_id,
  checked_off_at: null,
  check_changed_at: "2026-10-17T10:00:00.000000Z",
  ...changes,
})

const checkedOff = (at) => ({ checked_off_at: at, check_changed_at: at })

const supermarkt = (entries) => ({ id: 5, name: "Supermarkt", shared: true, areas, entries })

const change = (entry_id, checked_off, at) => ({ entry_id, checked_off, at })

describe("the queue", () => {
  test("keeps the last change per entry, in the order they happened", () => {
    let queue = []
    queue = enqueue(queue, change(1, true, "2026-10-17T10:02:00.000Z"))
    queue = enqueue(queue, change(2, true, "2026-10-17T10:03:00.000Z"))
    queue = enqueue(queue, change(1, false, "2026-10-17T10:04:00.000Z"))

    assert.deepEqual(queue, [
      change(2, true, "2026-10-17T10:03:00.000Z"),
      change(1, false, "2026-10-17T10:04:00.000Z"),
    ])
  })

  test("a sync removes what it sent and keeps what changed meanwhile", () => {
    const sent = [
      change(1, true, "2026-10-17T10:02:00.000Z"),
      change(2, true, "2026-10-17T10:03:00.000Z"),
    ]
    let queue = enqueue(sent, change(2, false, "2026-10-17T10:05:00.000Z"))
    queue = enqueue(queue, change(3, true, "2026-10-17T10:06:00.000Z"))

    assert.deepEqual(acknowledge(queue, sent), [
      change(2, false, "2026-10-17T10:05:00.000Z"),
      change(3, true, "2026-10-17T10:06:00.000Z"),
    ])
  })

  test("counts only the changes that still change an entry of the copy", () => {
    const lists = [
      supermarkt([
        entry(1, "Milch", 3),
        entry(2, "Eier", 3),
        entry(3, "Butter", 3, { check_changed_at: "2026-10-17T10:12:00.000000Z" }),
      ]),
    ]
    let queue = enqueue([], change(1, true, "2026-10-17T10:02:00.000Z"))
    queue = enqueue(queue, change(2, true, "2026-10-17T10:03:00.000Z"))
    queue = enqueue(queue, change(2, false, "2026-10-17T10:04:00.000Z"))
    queue = enqueue(queue, change(3, true, "2026-10-17T10:05:00.000Z"))
    queue = enqueue(queue, change(9, true, "2026-10-17T10:06:00.000Z"))

    assert.equal(pendingCount(lists, queue), 1)
  })

  test("says how many changes wait to sync", () => {
    assert.equal(pendingText(0), "Keine Änderung wartet auf den Abgleich.")
    assert.equal(pendingText(1), "1 Änderung wartet auf den Abgleich.")
    assert.equal(pendingText(3), "3 Änderungen warten auf den Abgleich.")
  })
})

describe("a list offline", () => {
  test("groups the open entries by area in the list's order, then by name", () => {
    const list = supermarkt([
      entry(1, "Zahnpasta", 7),
      entry(2, "Milch", 3, { detail: "2 l" }),
      entry(3, "Bananen", 1),
      entry(4, "Äpfel", 1),
    ])

    const view = listView(list, [])

    assert.equal(view.name, "Supermarkt")
    assert.equal(view.meta, "4 offen⁠ · Geteilt")
    assert.deepEqual(
      view.areas.map((area) => [area.name, area.entries.map((row) => row.name)]),
      [
        ["Obst und Gemüse", ["Äpfel", "Bananen"]],
        ["Kühlregal", ["Milch"]],
        ["Drogerie", ["Zahnpasta"]],
      ],
    )
    assert.deepEqual(view.areas[1].entries[0], {
      id: 2,
      name: "Milch",
      detail: "2 l",
      initial: "K",
      checkedOff: false,
    })
    assert.deepEqual(view.recent, [])
  })

  test("an entry checked off offline moves to the top of Zuletzt verwendet", () => {
    const list = supermarkt([
      entry(1, "Milch", 3),
      entry(2, "Eier", 3, checkedOff("2026-10-17T09:00:00.000000Z")),
    ])

    const view = listView(list, [change(1, true, "2026-10-17T10:02:00.000Z")])

    assert.deepEqual(view.areas, [])
    assert.equal(view.meta, "Nichts offen⁠ · Geteilt")
    assert.deepEqual(
      view.recent.map((row) => [row.name, row.checkedOff]),
      [
        ["Milch", true],
        ["Eier", true],
      ],
    )
  })

  test("an entry put back offline is open again in its area", () => {
    const list = supermarkt([entry(2, "Eier", 3, checkedOff("2026-10-17T09:00:00.000000Z"))])

    const view = listView(list, [change(2, false, "2026-10-17T10:02:00.000Z")])

    assert.deepEqual(
      view.areas.map((area) => [area.name, area.entries.map((row) => row.name)]),
      [["Kühlregal", ["Eier"]]],
    )
    assert.deepEqual(view.recent, [])
  })

  test("a queued change keeps the detail of a newer copy", () => {
    const list = supermarkt([entry(1, "Milch", 3, { detail: "3 l" })])

    const view = listView(list, [change(1, true, "2026-10-17T10:02:00.000Z")])

    assert.deepEqual(view.recent.map((row) => [row.name, row.detail]), [["Milch", "3 l"]])
  })

  test("a later change in the copy wins over an older queued one", () => {
    const list = supermarkt([entry(1, "Eier", 3, { check_changed_at: "2026-10-17T10:12:00.000000Z" })])

    const view = listView(list, [change(1, true, "2026-10-17T10:02:00.000Z")])

    assert.deepEqual(view.areas[0].entries.map((row) => row.name), ["Eier"])
    assert.deepEqual(view.recent, [])
  })

  test("Zuletzt verwendet shows the newest 30", () => {
    const minute = (i) => String(i).padStart(2, "0")
    const entries = Array.from({ length: 31 }, (_, i) =>
      entry(i + 1, `Artikel ${i + 1}`, 3, checkedOff(`2026-10-17T09:${minute(i)}:00.000000Z`)),
    )

    const view = listView(supermarkt(entries), [])

    assert.equal(view.recent.length, 30)
    assert.equal(view.recent[0].name, "Artikel 31")
    assert.equal(view.recent[29].name, "Artikel 2")
  })

  test("a private list says so", () => {
    const view = listView({ ...supermarkt([]), shared: false }, [])

    assert.equal(view.meta, "Nichts offen⁠ · Privat")
  })
})

describe("the start page offline", () => {
  test("splits the lists into shared and private ones, counting what is open with the queue", () => {
    const lists = [
      { id: 6, name: "Apotheke", shared: false, areas, entries: [] },
      supermarkt([entry(1, "Milch", 3), entry(2, "Eier", 3)]),
    ]

    const view = startView(lists, [change(1, true, "2026-10-17T10:02:00.000Z")])

    assert.deepEqual(view, {
      shared: [{ id: 5, name: "Supermarkt", initial: "S", meta: "1 offen" }],
      private: [{ id: 6, name: "Apotheke", initial: "A", meta: "Nichts offen" }],
    })
  })
})
