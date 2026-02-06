## Reverse key stream extraction helpers.

import ../types
import keys

proc toKeysRev*(entries: openArray[DbEntry]): seq[seq[byte]] =
  result = @[]
  var i = entries.len
  while i > 0:
    dec i
    result.add(entries[i].key)

proc firstKeyRev*(entries: openArray[DbEntry]): seq[byte] =
  let keys = toKeysRev(entries)
  if keys.len == 0:
    return @[]
  keys[0]

proc lastKeyRev*(entries: openArray[DbEntry]): seq[byte] =
  let keys = toKeysRev(entries)
  if keys.len == 0:
    return @[]
  keys[^1]

proc keyCountRev*(entries: openArray[DbEntry]): int =
  keyCount(entries)

proc hasKeysRev*(entries: openArray[DbEntry]): bool =
  hasKeys(entries)

proc toUniqueKeysRev*(entries: openArray[DbEntry]): seq[seq[byte]] =
  toKeysRev(entries).toUniqueKeys()
