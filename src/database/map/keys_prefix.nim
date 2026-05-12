## Map key iteration for a key prefix.

import open
import ../db

proc rawKeysPrefix*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  map.ensureOpen()
  map.db.keysPrefix(map.columnFamily, prefix)

proc keysPrefix*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  map.rawKeysPrefix(prefix)
