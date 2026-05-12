## Map key-value iteration for a key prefix.

import open
import ../db
import ../types

proc rawStreamPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbKeyValue] =
  map.ensureOpen()
  map.db.streamPrefix(map.columnFamily, prefix)

proc streamPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbKeyValue] =
  map.rawStreamPrefix(prefix)
