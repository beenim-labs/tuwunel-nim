## Clear helpers for map operations.

import open
import del
import count

type
  ClearReport* = object
    before*: int
    removed*: int
    after*: int

proc clear*(map: MapHandle): int =
  map.ensureOpen()
  map.truncate()

proc clearReport*(map: MapHandle): ClearReport =
  let before = map.count()
  let removed = map.clear()
  let after = map.count()
  ClearReport(before: before, removed: removed, after: after)

proc clearIfNonEmpty*(map: MapHandle): bool =
  if map.isEmpty:
    return false
  discard map.clear()
  true

proc clearAndCount*(map: MapHandle): tuple[before: int, after: int] =
  let before = map.count()
  discard map.clear()
  let after = map.count()
  (before: before, after: after)

proc clearPrefix*(map: MapHandle; prefix: openArray[byte]): int =
  map.delPrefix(prefix)
