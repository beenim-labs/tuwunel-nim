## Containment helpers for map operations.

import ../db
import ../serialization
import open

proc contains*(map: MapHandle; key: openArray[byte]): bool =
  map.ensureOpen()
  map.db.contains(map.columnFamily, key)

proc containsString*(map: MapHandle; key: string): bool =
  map.contains(toByteSeq(key))

proc containsAll*(map: MapHandle; keys: openArray[seq[byte]]): bool =
  map.ensureOpen()
  for key in keys:
    if not map.contains(key):
      return false
  true

proc containsAny*(map: MapHandle; keys: openArray[seq[byte]]): bool =
  map.ensureOpen()
  for key in keys:
    if map.contains(key):
      return true
  false

proc missingKeys*(map: MapHandle; keys: openArray[seq[byte]]): seq[seq[byte]] =
  result = @[]
  for key in keys:
    if not map.contains(key):
      result.add(key)

proc existingKeys*(map: MapHandle; keys: openArray[seq[byte]]): seq[seq[byte]] =
  result = @[]
  for key in keys:
    if map.contains(key):
      result.add(key)
