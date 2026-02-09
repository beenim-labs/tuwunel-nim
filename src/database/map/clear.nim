## Map clear helper.

import open
import ../types

proc clear*(map: MapHandle) =
  map.ensureOpen()
  raise newDbError("map.clear is not implemented for this backend")
