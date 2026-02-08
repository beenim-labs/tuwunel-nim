## Tried arithmetic — result type for try-arithmetic.
##
## Ported from Rust core/utils/math/tried.rs

const
  RustPath* = "core/utils/math/tried.rs"
  RustCrate* = "core"

type
  Tried*[T] = object
    ## Wrapper for try-arithmetic results. Similar to Expected
    ## but used in fallible contexts.
    value*: T
    ok*: bool

proc tried*[T](val: T): Tried[T] =
  Tried[T](value: val, ok: true)

proc failedTried*[T](): Tried[T] =
  Tried[T](ok: false)

proc unwrap*[T](t: Tried[T]): T =
  if not t.ok:
    raise newException(CatchableError, "tried arithmetic failed")
  t.value

proc isOk*[T](t: Tried[T]): bool = t.ok
proc isErr*[T](t: Tried[T]): bool = not t.ok
