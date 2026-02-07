## Reverse prefix key helpers for map operations.

import options
import rev_keys
import open
import keys_prefix
import keys

proc revKeysPrefix*(map: MapHandle; prefix: openArray[byte]): seq[seq[byte]] =
  map.revKeys(defaultMapReadOptions().withPrefix(prefix))

proc revFirstKeyPrefix*(map: MapHandle; prefix: openArray[byte]): seq[byte] =
  let listed = map.revKeysPrefix(prefix)
  if listed.len == 0:
    return @[]
  listed[0]

proc revLastKeyPrefix*(map: MapHandle; prefix: openArray[byte]): seq[byte] =
  let listed = map.keysPrefix(prefix)
  if listed.len == 0:
    return @[]
  listed[^1]

proc revKeysPrefixLimited*(map: MapHandle; prefix: openArray[byte]; limit: int): seq[seq[byte]] =
  map.revKeys(defaultMapReadOptions().withPrefix(prefix).withLimit(limit))

proc revKeyPrefixCount*(map: MapHandle; prefix: openArray[byte]): int =
  map.revKeysPrefix(prefix).len

proc revHasPrefixKeys*(map: MapHandle; prefix: openArray[byte]): bool =
  map.revKeysPrefix(prefix).len > 0

proc revKeysPrefixFrom*(
    map: MapHandle; prefix, startKey: openArray[byte]; includeStart = true): seq[seq[byte]] =
  let opts = defaultMapReadOptions().withPrefix(prefix).withStart(startKey, includeStart).reversed()
  map.keys(opts)
