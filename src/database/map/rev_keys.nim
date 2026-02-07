## Reverse key listing helpers for map operations.

import options
import keys
import open

proc revKeys*(map: MapHandle; options = defaultMapReadOptions()): seq[seq[byte]] =
  map.keys(options.reversed())

proc revFirstKey*(map: MapHandle; options = defaultMapReadOptions()): seq[byte] =
  let listed = map.revKeys(options.withLimit(1))
  if listed.len == 0:
    return @[]
  listed[0]

proc revLastKey*(map: MapHandle; options = defaultMapReadOptions()): seq[byte] =
  let listed = map.keys(options.withLimit(1))
  if listed.len == 0:
    return @[]
  listed[0]

proc revKeyCount*(map: MapHandle; options = defaultMapReadOptions()): int =
  map.revKeys(options).len

proc revHasAnyKey*(map: MapHandle; options = defaultMapReadOptions()): bool =
  map.revKeys(options.withLimit(1)).len > 0

proc revKeysLimited*(map: MapHandle; limit: int): seq[seq[byte]] =
  map.revKeys(defaultMapReadOptions().withLimit(limit))

proc revNthKey*(map: MapHandle; index: int; options = defaultMapReadOptions()): seq[byte] =
  let listed = map.revKeys(options)
  if index < 0 or index >= listed.len:
    return @[]
  listed[index]
