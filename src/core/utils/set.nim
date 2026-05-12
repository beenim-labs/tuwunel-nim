const
  RustPath* = "core/utils/set.rs"
  RustCrate* = "core"

proc containsValue[T](values: openArray[T]; target: T): bool =
  for value in values:
    if value == target:
      return true
  false

proc intersection*[T](input: openArray[seq[T]]): seq[T] =
  result = @[]
  if input.len == 0:
    return

  for target in input[0]:
    var keep = true
    for idx in 1 .. input.high:
      if not input[idx].containsValue(target):
        keep = false
        break
    if keep:
      result.add(target)

proc intersectionSorted*[T](input: openArray[seq[T]]): seq[T] =
  result = @[]
  if input.len == 0:
    return

  var positions = newSeq[int](max(input.len - 1, 0))
  for target in input[0]:
    var keep = true
    for idx in 1 .. input.high:
      let inputIdx = idx - 1
      while positions[inputIdx] < input[idx].len and input[idx][positions[inputIdx]] < target:
        inc positions[inputIdx]

      if positions[inputIdx] < input[idx].len and input[idx][positions[inputIdx]] == target:
        inc positions[inputIdx]
      else:
        keep = false
        break
    if keep:
      result.add(target)

proc intersectionSorted2*[T](a, b: openArray[T]): seq[T] =
  result = @[]
  var bIndex = 0
  for target in a:
    while bIndex < b.len and b[bIndex] < target:
      inc bIndex
    if bIndex < b.len and b[bIndex] == target:
      result.add(target)
      inc bIndex

proc intersectionSortedStream2*[T](a, b: openArray[T]): seq[T] =
  intersectionSorted2(a, b)

proc differenceSorted2*[T](a, b: openArray[T]): seq[T] =
  result = @[]
  var bIndex = 0
  for target in a:
    while bIndex < b.len and b[bIndex] < target:
      inc bIndex
    if bIndex < b.len and b[bIndex] == target:
      inc bIndex
    else:
      result.add(target)

proc differenceSortedStream2*[T](a, b: openArray[T]): seq[T] =
  differenceSorted2(a, b)
