## Expected arithmetic — result type for checked math.
##
## Ported from Rust core/utils/math/expected.rs

const
  RustPath* = "core/utils/math/expected.rs"
  RustCrate* = "core"

type
  Expected*[T] = object
    ## Wrapper for checked arithmetic results.
    value*: T
    valid*: bool

proc expected*[T](val: T): Expected[T] =
  Expected[T](value: val, valid: true)

proc invalidExpected*[T](): Expected[T] =
  Expected[T](valid: false)

proc unwrap*[T](e: Expected[T]): T =
  if not e.valid:
    raise newException(ArithmeticError, "expected arithmetic value was invalid")
  e.value

proc unwrapOr*[T](e: Expected[T]; default: T): T =
  if e.valid: e.value else: default

type ArithmeticError* = object of CatchableError
