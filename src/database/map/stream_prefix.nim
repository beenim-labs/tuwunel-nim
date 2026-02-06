## Prefix stream helpers for map operations.

import ../types
import options
import open
import stream

proc streamPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbEntry] =
  map.stream(defaultMapReadOptions().withPrefix(prefix))

proc streamPrefixLimited*(map: MapHandle; prefix: openArray[byte]; limit: int): seq[DbEntry] =
  map.stream(defaultMapReadOptions().withPrefix(prefix).withLimit(limit))

proc streamPrefixValues*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  result = @[]
  for entry in map.streamPrefix(prefix):
    result.add(entry.value)

proc streamPrefixKeys*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  result = @[]
  for entry in map.streamPrefix(prefix):
    result.add(entry.key)

proc streamPrefixCount*(map: MapHandle; prefix: openArray[byte]): int =
  map.streamPrefix(prefix).len

proc streamPrefixPairs*(
    map: MapHandle; prefix: openArray[byte]): seq[(seq[byte], seq[byte])] =
  map.streamPrefix(prefix).streamPairs(defaultMapReadOptions())
