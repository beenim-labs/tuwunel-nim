## Set utilities — intersection and difference operations.
##
## Ported from Rust core/utils/set.rs — iterator-based set operations.

const
  RustPath* = "core/utils/set.rs"
  RustCrate* = "core"

proc intersection*[T](sets: openArray[seq[T]]): seq[T] =
  ## Compute the intersection of multiple sets (sequences).
  ## Returns elements common to ALL input sets.
  if sets.len == 0:
    return @[]
  if sets.len == 1:
    return sets[0]
  result = @[]
  for item in sets[0]:
    var inAll = true
    for i in 1 ..< sets.len:
      var found = false
      for other in sets[i]:
        if other == item:
          found = true
          break
      if not found:
        inAll = false
        break
    if inAll:
      result.add item

proc intersectionSorted*[T](sets: openArray[seq[T]]): seq[T] =
  ## Compute intersection of sorted sets, leveraging sort order for efficiency.
  if sets.len == 0:
    return @[]
  if sets.len == 1:
    return sets[0]
  result = @[]
  # Use the first set and check presence in all others
  var indices = newSeq[int](sets.len)
  for item in sets[0]:
    var inAll = true
    for i in 1 ..< sets.len:
      # Advance index past items less than current
      while indices[i] < sets[i].len and sets[i][indices[i]] < item:
        inc indices[i]
      if indices[i] >= sets[i].len or sets[i][indices[i]] != item:
        inAll = false
        break
    if inAll:
      result.add item

proc difference*[T](a, b: seq[T]): seq[T] =
  ## Elements in a but not in b.
  result = @[]
  for item in a:
    var found = false
    for other in b:
      if other == item:
        found = true
        break
    if not found:
      result.add item

proc differenceSorted*[T](a, b: seq[T]): seq[T] =
  ## Difference of sorted sequences, leveraging sort order.
  result = @[]
  var j = 0
  for item in a:
    while j < b.len and b[j] < item:
      inc j
    if j >= b.len or b[j] != item:
      result.add item

proc union*[T](a, b: seq[T]): seq[T] =
  ## Union of two sequences (deduplicating).
  result = a
  for item in b:
    var found = false
    for existing in result:
      if existing == item:
        found = true
        break
    if not found:
      result.add item
