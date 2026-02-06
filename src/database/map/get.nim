## Map get helpers.

import std/options
import open
import ../db
import ../serialization

proc get*(map: MapHandle; key: openArray[byte]): Option[seq[byte]] =
  map.ensureOpen()
  map.db.get(map.columnFamily, key)

proc getString*(map: MapHandle; key: string): Option[string] =
  let value = map.get(toByteSeq(key))
  if value.isNone:
    return none(string)
  some(fromByteSeq(value.get))
