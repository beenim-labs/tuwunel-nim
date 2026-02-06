## Key stream extraction helpers.

import ../types

proc toKeys*(entries: openArray[DbEntry]): seq[seq[byte]] =
  result = @[]
  for entry in entries:
    result.add(entry.key)

proc toUniqueKeys*(entries: openArray[DbEntry]): seq[seq[byte]] =
  result = @[]
  var seen: seq[seq[byte]] = @[]
  for entry in entries:
    if entry.key in seen:
      continue
    seen.add(entry.key)
    result.add(entry.key)

proc firstKey*(entries: openArray[DbEntry]): seq[byte] =
  if entries.len == 0:
    return @[]
  entries[0].key

proc lastKey*(entries: openArray[DbEntry]): seq[byte] =
  if entries.len == 0:
    return @[]
  entries[^1].key

proc keyCount*(entries: openArray[DbEntry]): int =
  entries.len

proc hasKeys*(entries: openArray[DbEntry]): bool =
  entries.len > 0
