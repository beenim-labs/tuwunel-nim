## Reverse prefix stream helpers for map operations.

import ../types
import options
import rev_stream
import open

proc revStreamPrefix*(map: MapHandle; prefix: openArray[byte]): seq[DbEntry] =
  map.revStream(defaultMapReadOptions().withPrefix(prefix))

proc revStreamPrefixLimited*(map: MapHandle; prefix: openArray[byte]; limit: int): seq[DbEntry] =
  map.revStream(defaultMapReadOptions().withPrefix(prefix).withLimit(limit))

proc revStreamPrefixKeys*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  result = @[]
  for entry in map.revStreamPrefix(prefix):
    result.add(entry.key)

proc revStreamPrefixValues*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  result = @[]
  for entry in map.revStreamPrefix(prefix):
    result.add(entry.value)

proc revStreamPrefixPairs*(
    map: MapHandle; prefix: openArray[byte]): seq[(seq[byte], seq[byte])] =
  result = @[]
  for entry in map.revStreamPrefix(prefix):
    result.add((entry.key, entry.value))

proc revStreamPrefixCount*(map: MapHandle; prefix: openArray[byte]): int =
  map.revStreamPrefix(prefix).len

proc revStreamPrefixHead*(map: MapHandle; prefix: openArray[byte]): DbEntry =
  let entries = map.revStreamPrefixLimited(prefix, 1)
  if entries.len == 0:
    return (key: @[], value: @[])
  entries[0]
