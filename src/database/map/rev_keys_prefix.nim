## Reverse map key iteration for a key prefix.

import open
import ../db

proc revRawKeysPrefix*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  map.ensureOpen()
  map.db.revKeysPrefix(map.columnFamily, prefix)

proc revKeysPrefix*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  map.revRawKeysPrefix(prefix)
