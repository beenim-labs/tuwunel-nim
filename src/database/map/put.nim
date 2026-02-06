## Put helpers for map operations.

import ../db
import ../serialization
import open

proc put*(map: MapHandle; key, value: openArray[byte]) =
  map.ensureOpen()
  map.db.put(map.columnFamily, key, value)

proc putString*(map: MapHandle; key, value: string) =
  map.put(toByteSeq(key), toByteSeq(value))

proc putU64*(map: MapHandle; key: openArray[byte]; value: uint64) =
  map.put(key, encodeU64BE(value))

proc putMany*(map: MapHandle; entries: openArray[(seq[byte], seq[byte])]) =
  map.ensureOpen()
  for entry in entries:
    map.put(entry[0], entry[1])

proc putManyStrings*(map: MapHandle; entries: openArray[(string, string)]) =
  map.ensureOpen()
  for entry in entries:
    map.putString(entry[0], entry[1])

proc upsertString*(map: MapHandle; key, value: string): bool =
  let exists = map.db.contains(map.columnFamily, toByteSeq(key))
  map.putString(key, value)
  not exists

proc putIfMissing*(map: MapHandle; key, value: openArray[byte]): bool =
  map.ensureOpen()
  if map.db.contains(map.columnFamily, key):
    return false
  map.db.put(map.columnFamily, key, value)
  true
