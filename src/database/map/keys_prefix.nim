## Prefix key listing helpers for map operations.

import options
import keys
import open

proc keysPrefix*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  map.keys(defaultMapReadOptions().withPrefix(prefix))

proc firstKeyPrefix*(map: MapHandle; prefix: openArray[byte]): seq[byte] =
  let listed = map.keysPrefix(prefix)
  if listed.len == 0:
    return @[]
  listed[0]

proc lastKeyPrefix*(map: MapHandle; prefix: openArray[byte]): seq[byte] =
  let listed = map.keys(defaultMapReadOptions().withPrefix(prefix).reversed())
  if listed.len == 0:
    return @[]
  listed[0]

proc keyCountPrefix*(map: MapHandle; prefix: openArray[byte]): int =
  map.keysPrefix(prefix).len

proc hasPrefixKeys*(map: MapHandle; prefix: openArray[byte]): bool =
  map.keyCountPrefix(prefix) > 0

proc keysPrefixLimited*(map: MapHandle; prefix: openArray[byte]; limit: int): seq[seq[byte]] =
  map.keys(defaultMapReadOptions().withPrefix(prefix).withLimit(limit))

proc keysPrefixFrom*(
    map: MapHandle; prefix, startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  let opts = defaultMapReadOptions().withPrefix(prefix).withStart(startKey, includeStart)
  map.keys(opts)
