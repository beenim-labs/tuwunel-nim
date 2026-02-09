## Map put helpers.

import open
import ../db
import ../serialization

proc put*(map: MapHandle; key, value: openArray[byte]) =
  map.ensureOpen()
  map.db.put(map.columnFamily, key, value)

proc putString*(map: MapHandle; key, value: string) =
  map.put(toByteSeq(key), toByteSeq(value))
