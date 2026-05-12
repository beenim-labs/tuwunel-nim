import std/options

const
  RustPath* = "core/utils/option.rs"
  RustCrate* = "core"

proc mapAsync*[T, U](value: Option[T]; callback: proc(value: T): U): Option[U] =
  if value.isSome:
    some(callback(value.get()))
  else:
    none(U)

proc mapStream*[T, U](value: Option[T]; callback: proc(value: T): U): seq[U] =
  result = @[]
  let mapped = value.mapAsync(callback)
  if mapped.isSome:
    result.add(mapped.get())
