## Map contains helper.

import open
import ../db

proc contains*(map: MapHandle; key: openArray[byte]): bool =
  map.ensureOpen()
  map.db.contains(map.columnFamily, key)
