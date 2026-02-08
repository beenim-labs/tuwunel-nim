## ArrayVec extension — fixed-capacity growable array.
##
## Ported from Rust core/utils/arrayvec.rs — Nim uses seq with capacity.

const
  RustPath* = "core/utils/arrayvec.rs"
  RustCrate* = "core"

type
  ArrayVec*[T] = object
    ## Fixed-capacity growable array. Similar to Rust's arrayvec::ArrayVec.
    data: seq[T]
    capacity: int

proc newArrayVec*[T](capacity: int): ArrayVec[T] =
  ArrayVec[T](data: newSeqOfCap[T](capacity), capacity: capacity)

proc add*[T](v: var ArrayVec[T]; item: T) =
  if v.data.len >= v.capacity:
    raise newException(IndexDefect, "Insufficient buffer capacity")
  v.data.add item

proc extendFromSlice*[T](v: var ArrayVec[T]; items: openArray[T]) =
  for item in items:
    v.add item

proc len*[T](v: ArrayVec[T]): int = v.data.len
proc `[]`*[T](v: ArrayVec[T]; i: int): T = v.data[i]
proc `[]`*[T](v: var ArrayVec[T]; i: int): var T = v.data[i]

iterator items*[T](v: ArrayVec[T]): T =
  for item in v.data:
    yield item
