## Map key iteration from a lower-bound key.

import open
import ../db

proc rawKeysFrom*(map: MapHandle; fromKey: openArray[byte]): seq[seq[byte]] =
  map.ensureOpen()
  map.db.keysFrom(map.columnFamily, fromKey)

proc keysFrom*(map: MapHandle; fromKey: openArray[byte]): seq[seq[byte]] =
  map.rawKeysFrom(fromKey)
