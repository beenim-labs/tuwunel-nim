## Database utility helpers.

import types

proc compareBytes*(a, b: openArray[byte]): int =
  let m = min(a.len, b.len)
  var i = 0
  while i < m:
    if a[i] < b[i]:
      return -1
    if a[i] > b[i]:
      return 1
    inc i

  if a.len < b.len:
    return -1
  if a.len > b.len:
    return 1
  0

proc startsWithBytes*(data, prefix: openArray[byte]): bool =
  if prefix.len == 0:
    return true
  if data.len < prefix.len:
    return false

  var i = 0
  while i < prefix.len:
    if data[i] != prefix[i]:
      return false
    inc i
  true

proc asDbEntry*(key, value: openArray[byte]): DbEntry =
  (key: @key, value: @value)

proc keyLen*(entry: DbEntry): int =
  entry.key.len

proc valueLen*(entry: DbEntry): int =
  entry.value.len
