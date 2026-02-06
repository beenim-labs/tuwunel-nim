## Start-key stream helpers for map operations.

import ../types
import options
import open
import stream

proc streamFrom*(map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[DbEntry] =
  map.stream(defaultMapReadOptions().withStart(startKey, includeStart))

proc streamFromLimited*(
    map: MapHandle; startKey: openArray[byte]; limit: int; includeStart = true): seq[DbEntry] =
  let opts = defaultMapReadOptions().withStart(startKey, includeStart).withLimit(limit)
  map.stream(opts)

proc streamFromValues*(
    map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  result = @[]
  for entry in map.streamFrom(startKey, includeStart):
    result.add(entry.value)

proc streamFromKeys*(map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  result = @[]
  for entry in map.streamFrom(startKey, includeStart):
    result.add(entry.key)

proc streamFromCount*(map: MapHandle; startKey: openArray[byte]; includeStart = true): int =
  map.streamFrom(startKey, includeStart).len
