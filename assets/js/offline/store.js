// IndexedDB holds the offline copy of the lists and the queue of changes made without reception.

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

export const readLists = () => read("lists", [])
export const saveLists = (lists) => transact("readwrite", (store) => store.put(lists, "lists"))
export const forgetLists = () => transact("readwrite", (store) => store.delete("lists"))

export const readQueue = () => read("queue", [])
export const updateQueue = (change) => update("queue", [], change)
