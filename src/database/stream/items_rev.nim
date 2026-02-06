## Reverse item stream extraction helpers.

import ../types
import items

proc toItemsRev*(entries: openArray[DbEntry]): seq[(seq[byte], seq[byte])] =
  result = @[]
  var i = entries.len
  while i > 0:
    dec i
    result.add((entries[i].key, entries[i].value))

proc toValuesRev*(entries: openArray[DbEntry]): seq[seq[byte]] =
  result = @[]
  var i = entries.len
  while i > 0:
    dec i
    result.add(entries[i].value)

proc firstItemRev*(entries: openArray[DbEntry]): (seq[byte], seq[byte]) =
  let items = toItemsRev(entries)
  if items.len == 0:
    return (@[], @[])
  items[0]

proc lastItemRev*(entries: openArray[DbEntry]): (seq[byte], seq[byte]) =
  let items = toItemsRev(entries)
  if items.len == 0:
    return (@[], @[])
  items[^1]

proc itemCountRev*(entries: openArray[DbEntry]): int =
  itemCount(entries)

proc hasItemsRev*(entries: openArray[DbEntry]): bool =
  hasItems(entries)
