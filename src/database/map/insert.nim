## Insert compatibility helpers for map operations.

import open
import put
import contains

proc insert*(map: MapHandle; key, value: openArray[byte]) =
  map.put(key, value)

proc insertString*(map: MapHandle; key, value: string) =
  map.putString(key, value)

proc insertIfMissing*(map: MapHandle; key, value: openArray[byte]): bool =
  map.putIfMissing(key, value)

proc insertMany*(map: MapHandle; entries: openArray[(seq[byte], seq[byte])]) =
  for entry in entries:
    map.insert(entry[0], entry[1])

proc insertUnique*(map: MapHandle; entries: openArray[(seq[byte], seq[byte])]): int =
  result = 0
  for entry in entries:
    if not map.contains(entry[0]):
      map.insert(entry[0], entry[1])
      inc result

proc insertedCount*(map: MapHandle; entries: openArray[(seq[byte], seq[byte])]): int =
  result = 0
  for entry in entries:
    if map.insertIfMissing(entry[0], entry[1]):
      inc result

proc insertedAny*(map: MapHandle; entries: openArray[(seq[byte], seq[byte])]): bool =
  map.insertedCount(entries) > 0

proc insertedAll*(map: MapHandle; entries: openArray[(seq[byte], seq[byte])]): bool =
  map.insertedCount(entries) == entries.len
