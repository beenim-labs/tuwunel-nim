## Delete helpers for map operations.

import ../db
import ../serialization
import open

proc del*(map: MapHandle; key: openArray[byte]): bool =
  map.ensureOpen()
  map.db.del(map.columnFamily, key)

proc delString*(map: MapHandle; key: string): bool =
  map.del(toByteSeq(key))

proc delMany*(map: MapHandle; keys: openArray[seq[byte]]): int =
  map.ensureOpen()
  result = 0
  for key in keys:
    if map.del(key):
      inc result

proc delPrefix*(map: MapHandle; prefix: openArray[byte]): int =
  map.ensureOpen()
  var toDelete: seq[seq[byte]] = @[]
  for entry in map.readPrefix(prefix):
    toDelete.add(entry.key)

  for key in toDelete:
    if map.del(key):
      inc result

proc truncate*(map: MapHandle): int =
  map.ensureOpen()
  map.db.clearColumnFamily(map.columnFamily)
