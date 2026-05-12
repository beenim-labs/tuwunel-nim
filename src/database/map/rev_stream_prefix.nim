## Reverse map key-value iteration for a key prefix.

import open
import ../db
import ../types

proc revRawStreamPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbKeyValue] =
  map.ensureOpen()
  map.db.revStreamPrefix(map.columnFamily, prefix)

proc revStreamPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbKeyValue] =
  map.revRawStreamPrefix(prefix)
