## Map key-value iteration helpers.

import open
import ../db
import ../types

proc rawStream*(map: MapHandle): seq[DbKeyValue] =
  map.ensureOpen()
  map.db.stream(map.columnFamily)

proc stream*(map: MapHandle): seq[DbKeyValue] =
  map.rawStream()
