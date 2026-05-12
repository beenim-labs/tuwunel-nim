const
  RustPath* = "core/utils/arrayvec.rs"
  RustCrate* = "core"

type ArrayVec*[T] = object
  capacityValue: int
  values: seq[T]

proc newArrayVec*[T](capacity: int): ArrayVec[T] =
  if capacity < 0:
    raise newException(ValueError, "capacity must not be negative")
  ArrayVec[T](capacityValue: capacity, values: @[])

proc len*[T](vec: ArrayVec[T]): int =
  vec.values.len

proc capacity*[T](vec: ArrayVec[T]): int =
  vec.capacityValue

proc toSeq*[T](vec: ArrayVec[T]): seq[T] =
  vec.values

proc add*[T](vec: var ArrayVec[T]; value: T): var ArrayVec[T] {.discardable.} =
  if vec.values.len >= vec.capacityValue:
    raise newException(ValueError, "Insufficient buffer capacity to extend from slice")
  vec.values.add(value)
  vec

proc extendFromSlice*[T](vec: var ArrayVec[T]; other: openArray[T]): var ArrayVec[T] {.discardable.} =
  if vec.values.len + other.len > vec.capacityValue:
    raise newException(ValueError, "Insufficient buffer capacity to extend from slice")
  for value in other:
    vec.values.add(value)
  vec
