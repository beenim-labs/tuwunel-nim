## Item stream extraction helpers.

import ../types

proc toItems*(entries: openArray[DbEntry]): seq[(seq[byte], seq[byte])] =
  result = @[]
  for entry in entries:
    result.add((entry.key, entry.value))

proc toValues*(entries: openArray[DbEntry]): seq[seq[byte]] =
  result = @[]
  for entry in entries:
    result.add(entry.value)

proc firstItem*(entries: openArray[DbEntry]): (seq[byte], seq[byte]) =
  if entries.len == 0:
    return (@[], @[])
  (entries[0].key, entries[0].value)

proc lastItem*(entries: openArray[DbEntry]): (seq[byte], seq[byte]) =
  if entries.len == 0:
    return (@[], @[])
  (entries[^1].key, entries[^1].value)

proc itemCount*(entries: openArray[DbEntry]): int =
  entries.len

proc hasItems*(entries: openArray[DbEntry]): bool =
  entries.len > 0

proc toEntrySeq*(items: openArray[(seq[byte], seq[byte])]): seq[DbEntry] =
  result = @[]
  for item in items:
    result.add((key: item[0], value: item[1]))
