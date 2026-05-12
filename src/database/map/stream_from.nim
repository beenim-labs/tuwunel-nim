## Map key-value iteration from a lower-bound key.

import open
import ../db
import ../types

proc rawStreamFrom*(map: MapHandle; fromKey: openArray[byte]): seq[DbKeyValue] =
  map.ensureOpen()
  map.db.streamFrom(map.columnFamily, fromKey)

proc streamFrom*(map: MapHandle; fromKey: openArray[byte]): seq[DbKeyValue] =
  map.rawStreamFrom(fromKey)
