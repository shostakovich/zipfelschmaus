// IndexedDB holds the offline copy of the lists and, per user, the queue of changes made without
// reception, so that a queue only ever syncs under its user's session.

const DATABASE = "zipfelschmaus"
const STORE = "offline"

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1)
    request.onupgradeneeded = () => request.result.createObjectStore(STORE)
    request.onsuccess = () => resolve(request.result)
    request.onerror = () => reject(request.error)
  })
}

async function transact(mode, work) {
  const database = await openDatabase()

  return new Promise((resolve, reject) => {
    const transaction = database.transaction(STORE, mode)
    let result
    work(transaction.objectStore(STORE), (value) => (result = value))
    transaction.oncomplete = () => {
      database.close()
      resolve(result)
    }
    transaction.onerror = transaction.onabort = () => {
      database.close()
      reject(transaction.error)
    }
  })
}

const read = (key, fallback) =>
  transact("readonly", (store, done) => {
    const request = store.get(key)
    request.onsuccess = () => done(request.result ?? fallback)
  })

// Read and write in one transaction, so a sync and a tap never overwrite each other.
const update = (key, fallback, change) =>
  transact("readwrite", (store, done) => {
    const request = store.get(key)
    request.onsuccess = () => {
      const value = change(request.result ?? fallback)
      store.put(value, key)
      done(value)
    }
  })

export const readCopy = () => read("copy", { user_id: null, lists: [] })
export const saveCopy = (copy) => transact("readwrite", (store) => store.put(copy, "copy"))
export const forgetCopy = () => transact("readwrite", (store) => store.delete("copy"))

const queueKey = (userId) => `queue-${userId}`
export const readQueue = (userId) => read(queueKey(userId), [])
export const updateQueue = (userId, change) => update(queueKey(userId), [], change)
