## Reverse stream helpers for map operations.

import ../types
import options
import stream
import open

proc revStream*(map: MapHandle; options = defaultMapReadOptions()): seq[DbEntry] =
  map.stream(options.reversed())

proc revStreamLimited*(map: MapHandle; limit: int): seq[DbEntry] =
  map.revStream(defaultMapReadOptions().withLimit(limit))

proc revStreamKeys*(map: MapHandle; options = defaultMapReadOptions()): seq[seq[byte]] =
  result = @[]
  for entry in map.revStream(options):
    result.add(entry.key)

proc revStreamValues*(map: MapHandle; options = defaultMapReadOptions()): seq[seq[byte]] =
  result = @[]
  for entry in map.revStream(options):
    result.add(entry.value)

proc revStreamPairs*(map: MapHandle; options = defaultMapReadOptions()): seq[(seq[byte], seq[byte])] =
  result = @[]
  for entry in map.revStream(options):
    result.add((entry.key, entry.value))

proc revStreamCount*(map: MapHandle; options = defaultMapReadOptions()): int =
  map.revStream(options).len

proc revStreamHead*(map: MapHandle; options = defaultMapReadOptions()): DbEntry =
  let entries = map.revStream(options.withLimit(1))
  if entries.len == 0:
    return (key: @[], value: @[])
  entries[0]
