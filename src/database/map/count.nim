## Count helpers for map operations.

import ../db
import open

proc count*(map: MapHandle): int =
  map.ensureOpen()
  map.db.count(map.columnFamily)

proc isEmpty*(map: MapHandle): bool =
  map.count() == 0

proc nonEmpty*(map: MapHandle): bool =
  map.count() > 0

proc countPrefix*(map: MapHandle; prefix: openArray[byte]): int =
  map.ensureOpen()
  result = 0
  for _ in map.readPrefix(prefix):
    inc result

proc countFrom*(map: MapHandle; startKey: openArray[byte]): int =
  map.ensureOpen()
  result = 0
  for _ in map.readFrom(startKey):
    inc result

proc countWithLimit*(map: MapHandle; limit: int): int =
  map.ensureOpen()
  let opts = defaultMapReadOptions().withLimit(limit)
  map.read(opts).len

proc countReverse*(map: MapHandle): int =
  map.ensureOpen()
  map.readReverse().len
