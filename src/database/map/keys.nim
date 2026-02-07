## Key listing helpers for map operations.

import ../types
import options
import open

proc keys*(map: MapHandle; options = defaultMapReadOptions()): seq[seq[byte]] =
  result = @[]
  for entry in map.read(options):
    result.add(entry.key)

proc firstKey*(map: MapHandle; options = defaultMapReadOptions()): seq[byte] =
  let listed = map.keys(options.withLimit(1))
  if listed.len == 0:
    return @[]
  listed[0]

proc lastKey*(map: MapHandle; options = defaultMapReadOptions()): seq[byte] =
  let listed = map.keys(options.reversed().withLimit(1))
  if listed.len == 0:
    return @[]
  listed[0]

proc keyEntries*(map: MapHandle; options = defaultMapReadOptions()): seq[DbEntry] =
  map.read(options)

proc keyCount*(map: MapHandle; options = defaultMapReadOptions()): int =
  map.keys(options).len

proc hasAnyKey*(map: MapHandle; options = defaultMapReadOptions()): bool =
  map.keys(options.withLimit(1)).len > 0

proc nthKey*(map: MapHandle; index: int; options = defaultMapReadOptions()): seq[byte] =
  let listed = map.keys(options)
  if index < 0 or index >= listed.len:
    return @[]
  listed[index]
