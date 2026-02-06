## Map batch-get helper.

import std/options
import open
import get

proc getBatch*(map: MapHandle; keys: openArray[seq[byte]]): seq[Option[seq[byte]]] =
  result = @[]
  for key in keys:
    result.add(map.get(key))
