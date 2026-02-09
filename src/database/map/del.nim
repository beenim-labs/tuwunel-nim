## Map delete helper.

import open
import ../db

proc del*(map: MapHandle; key: openArray[byte]): bool =
  map.ensureOpen()
  map.db.del(map.columnFamily, key)
