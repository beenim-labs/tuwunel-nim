## Reverse map key iteration from an upper-bound key.

import open
import ../db

proc revRawKeysFrom*(map: MapHandle; fromKey: openArray[byte]): seq[seq[byte]] =
  map.ensureOpen()
  map.db.revKeysFrom(map.columnFamily, fromKey)

proc revKeysFrom*(map: MapHandle; fromKey: openArray[byte]): seq[seq[byte]] =
  map.revRawKeysFrom(fromKey)
