## MutexMap — keyed lock map with RAII-style guard.
##
## Ported from Rust core/utils/mutex_map.rs

import std/[tables, locks, hashes]

const
  RustPath* = "core/utils/mutex_map.rs"
  RustCrate* = "core"

type
  MutexMap*[K, V] = ref object
    ## Map of mutexes, keyed by K. Each key gets its own lock.
    mapLock: Lock
    entries: Table[K, ref MutexMapEntry[V]]

  MutexMapEntry[V] = object
    lock: Lock
    value: V
    refCount: int

  MutexMapGuard*[K, V] = object
    ## RAII guard — holds the lock for a specific key.
    map: MutexMap[K, V]
    key: K
    entry: ref MutexMapEntry[V]

proc newMutexMap*[K, V](): MutexMap[K, V] =
  ## Create a new MutexMap.
  result = MutexMap[K, V](entries: initTable[K, ref MutexMapEntry[V]]())
  initLock(result.mapLock)

proc lock*[K, V](m: MutexMap[K, V]; key: K): MutexMapGuard[K, V] =
  ## Acquire a lock for the given key. Creates entry if absent.
  acquire(m.mapLock)
  if key notin m.entries:
    var entry = new MutexMapEntry[V]
    initLock(entry.lock)
    entry.refCount = 0
    m.entries[key] = entry
  let entry = m.entries[key]
  inc entry.refCount
  release(m.mapLock)
  acquire(entry.lock)
  MutexMapGuard[K, V](map: m, key: key, entry: entry)

proc tryLock*[K, V](m: MutexMap[K, V]; key: K): tuple[ok: bool; guard: MutexMapGuard[K, V]] =
  ## Try to acquire a lock for the given key without blocking.
  acquire(m.mapLock)
  if key notin m.entries:
    var entry = new MutexMapEntry[V]
    initLock(entry.lock)
    entry.refCount = 0
    m.entries[key] = entry
  let entry = m.entries[key]
  inc entry.refCount
  release(m.mapLock)
  if tryAcquire(entry.lock):
    (true, MutexMapGuard[K, V](map: m, key: key, entry: entry))
  else:
    acquire(m.mapLock)
    dec entry.refCount
    if entry.refCount <= 0:
      m.entries.del(key)
    release(m.mapLock)
    (false, MutexMapGuard[K, V]())

proc unlock*[K, V](guard: var MutexMapGuard[K, V]) =
  ## Release the lock held by this guard.
  if guard.entry != nil:
    release(guard.entry.lock)
    acquire(guard.map.mapLock)
    dec guard.entry.refCount
    if guard.entry.refCount <= 0:
      guard.map.entries.del(guard.key)
    release(guard.map.mapLock)
    guard.entry = nil

proc value*[K, V](guard: MutexMapGuard[K, V]): var V =
  ## Access the value held by this guard.
  guard.entry.value

proc `=destroy`*[K, V](guard: MutexMapGuard[K, V]) =
  ## RAII cleanup — release lock on guard destruction.
  if guard.entry != nil:
    release(guard.entry.lock)
    # Note: in a proper RAII impl we'd also cleanup the map entry

proc contains*[K, V](m: MutexMap[K, V]; key: K): bool =
  acquire(m.mapLock)
  result = key in m.entries
  release(m.mapLock)

proc isEmpty*[K, V](m: MutexMap[K, V]): bool =
  acquire(m.mapLock)
  result = m.entries.len == 0
  release(m.mapLock)

proc len*[K, V](m: MutexMap[K, V]): int =
  acquire(m.mapLock)
  result = m.entries.len
  release(m.mapLock)
