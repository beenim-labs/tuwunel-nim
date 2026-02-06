## Map insert helper.

import open
import put

proc insert*(map: MapHandle; key, value: openArray[byte]) =
  map.put(key, value)
