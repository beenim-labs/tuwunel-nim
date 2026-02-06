## Map handle and opening helpers.

import ../db
import ../types
import options

type
  MapHandle* = object
    db*: DatabaseHandle
    columnFamily*: string

proc openMap*(db: DatabaseHandle; columnFamily: string): MapHandle =
  if db.isNil:
    raise newDbError("DatabaseHandle is nil")
  if columnFamily.len == 0:
    raise newDbError("Column family cannot be empty")

  discard db.listColumnFamilies()
  MapHandle(db: db, columnFamily: columnFamily)

proc ensureOpen*(map: MapHandle) =
  if map.db.isNil:
    raise newDbError("MapHandle is closed")
  if map.columnFamily.len == 0:
    raise newDbError("MapHandle column family is empty")

proc snapshot*(map: MapHandle): seq[DbEntry] =
  map.ensureOpen()
  map.db.entries(map.columnFamily)

proc read*(map: MapHandle; options = defaultMapReadOptions()): seq[DbEntry] =
  filterEntries(map.snapshot(), options)

proc readPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbEntry] =
  map.read(defaultMapReadOptions().withPrefix(prefix))

proc readFrom*(
    map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[DbEntry] =
  map.read(defaultMapReadOptions().withStart(startKey, includeStart))

proc readReverse*(map: MapHandle; options = defaultMapReadOptions()): seq[DbEntry] =
  map.read(options.reversed())
