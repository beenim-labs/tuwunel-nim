## Map count helper.

import open
import ../db

proc count*(map: MapHandle): int =
  map.ensureOpen()
  map.db.count(map.columnFamily)
