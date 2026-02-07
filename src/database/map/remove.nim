## Remove compatibility helpers for map operations.

import open
import del

proc remove*(map: MapHandle; key: openArray[byte]): bool =
  map.del(key)

proc removeString*(map: MapHandle; key: string): bool =
  map.delString(key)

proc removeMany*(map: MapHandle; keys: openArray[seq[byte]]): int =
  result = 0
  for key in keys:
    if map.remove(key):
      inc result

proc removePrefix*(map: MapHandle; prefix: openArray[byte]): int =
  map.delPrefix(prefix)

proc removeAll*(map: MapHandle): int =
  map.truncate()

proc removeReport*(map: MapHandle; keys: openArray[seq[byte]]): tuple[removed: int, remaining: int] =
  let removedCount = map.removeMany(keys)
  (removed: removedCount, remaining: max(0, keys.len - removedCount))

proc removedAny*(map: MapHandle; keys: openArray[seq[byte]]): bool =
  map.removeMany(keys) > 0

proc removedAll*(map: MapHandle; keys: openArray[seq[byte]]): bool =
  map.removeMany(keys) == keys.len

proc removeUntilMissing*(map: MapHandle; key: openArray[byte]): int =
  result = 0
  while map.remove(key):
    inc result
