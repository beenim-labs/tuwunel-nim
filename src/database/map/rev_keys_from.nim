## Reverse start-key key helpers for map operations.

import options
import rev_keys
import open
import keys

proc revKeysFrom*(map: MapHandle; startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  map.revKeys(defaultMapReadOptions().withStart(startKey, includeStart))

proc revKeysFromLimited*(
    map: MapHandle; startKey: openArray[byte]; limit: int; includeStart = true): seq[seq[byte]] =
  let opts = defaultMapReadOptions().withStart(startKey, includeStart).withLimit(limit).reversed()
  map.keys(opts)

proc revFirstKeyFrom*(map: MapHandle; startKey: openArray[byte]): seq[byte] =
  let listed = map.revKeysFrom(startKey)
  if listed.len == 0:
    return @[]
  listed[0]

proc revKeysFromCount*(map: MapHandle; startKey: openArray[byte]; includeStart = true): int =
  map.revKeysFrom(startKey, includeStart).len

proc revHasKeysFrom*(map: MapHandle; startKey: openArray[byte]): bool =
  map.revKeysFromLimited(startKey, 1).len > 0

proc revKeysFromPrefix*(
    map: MapHandle; startKey, prefix: openArray[byte]; includeStart = true): seq[seq[byte]] =
  let opts = defaultMapReadOptions().withStart(startKey, includeStart).withPrefix(prefix).reversed()
  map.keys(opts)

proc revKeysFromRange*(
    map: MapHandle; startKey, stopKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  result = @[]
  for key in map.revKeysFrom(startKey, includeStart):
    if compareBytes(key, stopKey) < 0:
      break
    result.add(key)
