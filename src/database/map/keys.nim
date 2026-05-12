## Map key iteration helpers.

import open
import ../db

proc rawKeys*(map: MapHandle): seq[seq[byte]] =
  map.ensureOpen()
  map.db.keys(map.columnFamily)

proc keys*(map: MapHandle): seq[seq[byte]] =
  map.rawKeys()
