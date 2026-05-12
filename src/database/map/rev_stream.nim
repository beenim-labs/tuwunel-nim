## Reverse map key-value iteration helpers.

import open
import ../db
import ../types

proc revRawStream*(map: MapHandle): seq[DbKeyValue] =
  map.ensureOpen()
  map.db.revStream(map.columnFamily)

proc revStream*(map: MapHandle): seq[DbKeyValue] =
  map.revRawStream()
