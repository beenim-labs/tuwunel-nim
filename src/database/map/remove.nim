## Map remove helper.

import open
import del

proc remove*(map: MapHandle; key: openArray[byte]): bool =
  map.del(key)
