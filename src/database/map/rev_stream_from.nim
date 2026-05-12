## Reverse map key-value iteration from an upper-bound key.

import open
import ../db
import ../types

proc revRawStreamFrom*(map: MapHandle; fromKey: openArray[byte]): seq[DbKeyValue] =
  map.ensureOpen()
  map.db.revStreamFrom(map.columnFamily, fromKey)

proc revStreamFrom*(map: MapHandle; fromKey: openArray[byte]): seq[DbKeyValue] =
  map.revRawStreamFrom(fromKey)
