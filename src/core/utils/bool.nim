import std/options

const
  RustPath* = "core/utils/bool.rs"
  RustCrate* = "core"

type
  Unit* = object
  BoolResult* = tuple[ok: bool, message: string]
  BoolValueResult*[T] = tuple[ok: bool, value: T, message: string]

proc andOption*[T](value: bool; option: Option[T]): Option[T] =
  if value:
    option
  else:
    none(T)

proc andIs*(value, other: bool): bool =
  value and other

proc andIf*(value: bool; predicate: proc(): bool): bool =
  value and predicate()

proc andThen*[T](value: bool; callback: proc(): Option[T]): Option[T] =
  if value:
    callback()
  else:
    none(T)

proc cloneOr*[T](value: bool; fallback, selected: T): T =
  if value:
    selected
  else:
    fallback

proc copyOr*[T](value: bool; fallback, selected: T): T =
  cloneOr(value, fallback, selected)

proc expect*(value: bool; message: string): bool =
  if not value:
    raise newException(AssertionDefect, message)
  true

proc expectFalse*(value: bool; message: string): bool =
  if value:
    raise newException(AssertionDefect, message)
  false

proc intoOption*(value: bool): Option[Unit] =
  if value:
    some(Unit())
  else:
    none(Unit)

proc intoResult*(value: bool): BoolResult =
  if value:
    (true, "")
  else:
    (false, "()")

proc isFalse*(value: bool): bool =
  not value

proc mapBool*[T](value: bool; callback: proc(value: bool): T): T =
  callback(value)

proc mapOkOr*[T](value: bool; message: string; callback: proc(): T): BoolValueResult[T] =
  if value:
    (true, callback(), "")
  else:
    (false, default(T), message)

proc mapOr*[T](value: bool; fallback: T; callback: proc(): T): T =
  if value:
    callback()
  else:
    fallback

proc mapOrElse*[T](value: bool; fallback: proc(): T; callback: proc(): T): T =
  if value:
    callback()
  else:
    fallback()

proc okOr*(value: bool; message: string): BoolResult =
  if value:
    (true, "")
  else:
    (false, message)

proc okOrElse*(value: bool; message: proc(): string): BoolResult =
  if value:
    (true, "")
  else:
    (false, message())

proc orOption*[T](value: bool; callback: proc(): T): Option[T] =
  if value:
    none(T)
  else:
    some(callback())

proc orSome*[T](value: bool; selected: T): Option[T] =
  if value:
    none(T)
  else:
    some(selected)

proc thenAsync*[T](value: bool; callback: proc(): T): Option[T] =
  if value:
    some(callback())
  else:
    none(T)

proc thenNone*[T](value: bool): Option[T] =
  discard value
  none(T)

proc thenOkOr*[T](value: bool; selected: T; message: string): BoolValueResult[T] =
  mapOkOr(value, message, proc(): T = selected)

proc thenOkOrElse*[T](value: bool; selected: T; message: proc(): string): BoolValueResult[T] =
  if value:
    (true, selected, "")
  else:
    (false, default(T), message())
