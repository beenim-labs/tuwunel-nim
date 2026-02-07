## Stream helpers for map operations.

import ../types
import options
import open

proc stream*(map: MapHandle; options = defaultMapReadOptions()): seq[DbEntry] =
  map.read(options)

proc streamLimited*(map: MapHandle; limit: int): seq[DbEntry] =
  map.stream(defaultMapReadOptions().withLimit(limit))

proc streamPairs*(map: MapHandle; options = defaultMapReadOptions()): seq[(seq[byte], seq[byte])] =
  result = @[]
  for entry in map.stream(options):
    result.add((entry.key, entry.value))

proc streamValues*(map: MapHandle; options = defaultMapReadOptions()): seq[seq[byte]] =
  result = @[]
  for entry in map.stream(options):
    result.add(entry.value)

proc streamKeys*(map: MapHandle; options = defaultMapReadOptions()): seq[seq[byte]] =
  result = @[]
  for entry in map.stream(options):
    result.add(entry.key)

proc streamCount*(map: MapHandle; options = defaultMapReadOptions()): int =
  map.stream(options).len

proc streamHead*(map: MapHandle; options = defaultMapReadOptions()): DbEntry =
  let entries = map.stream(options.withLimit(1))
  if entries.len == 0:
    return (key: @[], value: @[])
  entries[0]
