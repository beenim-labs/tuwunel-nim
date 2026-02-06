## Stream utilities for deterministic entry projection.

import types
import stream/keys
import stream/keys_rev
import stream/items
import stream/items_rev

proc forwardEntries*(entries: openArray[DbEntry]): seq[DbEntry] =
  @entries

proc reverseEntries*(entries: openArray[DbEntry]): seq[DbEntry] =
  result = @[]
  var i = entries.len
  while i > 0:
    dec i
    result.add(entries[i])

proc takeEntries*(entries: openArray[DbEntry]; limit: int): seq[DbEntry] =
  result = @[]
  let n = max(0, limit)
  var i = 0
  while i < entries.len and i < n:
    result.add(entries[i])
    inc i

proc dropEntries*(entries: openArray[DbEntry]; count: int): seq[DbEntry] =
  result = @[]
  let n = max(0, count)
  var i = n
  while i < entries.len:
    result.add(entries[i])
    inc i

proc collectKeyStream*(entries: openArray[DbEntry]): seq[seq[byte]] =
  toKeys(entries)

proc collectKeyStreamRev*(entries: openArray[DbEntry]): seq[seq[byte]] =
  toKeysRev(entries)

proc collectItemStream*(entries: openArray[DbEntry]): seq[(seq[byte], seq[byte])] =
  toItems(entries)

proc collectItemStreamRev*(entries: openArray[DbEntry]): seq[(seq[byte], seq[byte])] =
  toItemsRev(entries)

export keys
export keys_rev
export items
export items_rev
