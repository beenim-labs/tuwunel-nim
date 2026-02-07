## Start-key key listing helpers for map operations.

import options
import keys
import open

proc keysFrom*(map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  map.keys(defaultMapReadOptions().withStart(startKey, includeStart))

proc keysFromLimited*(
    map: MapHandle; startKey: openArray[byte]; limit: int; includeStart = true): seq[seq[byte]] =
  let opts = defaultMapReadOptions().withStart(startKey, includeStart).withLimit(limit)
  map.keys(opts)

proc firstKeyFrom*(map: MapHandle; startKey: openArray[byte]): seq[byte] =
  let listed = map.keysFrom(startKey)
  if listed.len == 0:
    return @[]
  listed[0]

proc keyCountFrom*(map: MapHandle; startKey: openArray[byte]; includeStart = true): int =
  map.keysFrom(startKey, includeStart).len

proc hasKeysFrom*(map: MapHandle; startKey: openArray[byte]): bool =
  map.keysFromLimited(startKey, 1).len > 0

proc keysFromPrefix*(
    map: MapHandle; startKey, prefix: openArray[byte]; includeStart = true): seq[seq[byte]] =
  let opts = defaultMapReadOptions().withStart(startKey, includeStart).withPrefix(prefix)
  map.keys(opts)

proc keysFromRange*(
    map: MapHandle; startKey, stopKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  result = @[]
  for key in map.keysFrom(startKey, includeStart):
    if compareBytes(key, stopKey) > 0:
      break
    result.add(key)
