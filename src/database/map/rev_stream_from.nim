## Reverse start-key stream helpers for map operations.

import ../types
import options
import rev_stream
import open

proc revStreamFrom*(map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[DbEntry] =
  map.revStream(defaultMapReadOptions().withStart(startKey, includeStart))

proc revStreamFromLimited*(
    map: MapHandle; startKey: openArray[byte]; limit: int; includeStart = true): seq[DbEntry] =
  let opts = defaultMapReadOptions().withStart(startKey, includeStart).withLimit(limit)
  map.revStream(opts)

proc revStreamFromKeys*(
    map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  result = @[]
  for entry in map.revStreamFrom(startKey, includeStart):
    result.add(entry.key)

proc revStreamFromValues*(
    map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  result = @[]
  for entry in map.revStreamFrom(startKey, includeStart):
    result.add(entry.value)

proc revStreamFromCount*(map: MapHandle; startKey: openArray[byte]; includeStart = true): int =
  map.revStreamFrom(startKey, includeStart).len
