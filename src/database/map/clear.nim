## Map clear helper.

import open
import ../db

proc clear*(map: MapHandle) =
  map.ensureOpen()
  map.db.clear(map.columnFamily)
