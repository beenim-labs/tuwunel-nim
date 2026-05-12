## Reverse map key iteration helpers.

import open
import ../db

proc revRawKeys*(map: MapHandle): seq[seq[byte]] =
  map.ensureOpen()
  map.db.revKeys(map.columnFamily)

proc revKeys*(map: MapHandle): seq[seq[byte]] =
  map.revRawKeys()
