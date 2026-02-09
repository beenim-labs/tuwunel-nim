## Database map handle and open helper.

import ../db
import ../types

type
  MapHandle* = object
    db*: DatabaseHandle
    columnFamily*: string

proc openMap*(db: DatabaseHandle; columnFamily: string): MapHandle =
  if db.isNil:
    raise newDbError("DatabaseHandle is nil")
  if columnFamily.len == 0:
    raise newDbError("Column family cannot be empty")
  MapHandle(db: db, columnFamily: columnFamily)

proc ensureOpen*(map: MapHandle) =
  if map.db.isNil:
    raise newDbError("MapHandle is not open")
  if map.columnFamily.len == 0:
    raise newDbError("MapHandle column family is empty")
