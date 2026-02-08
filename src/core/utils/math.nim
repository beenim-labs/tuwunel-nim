## Checked and validated arithmetic utilities.
##
## Ported from Rust core/utils/math.rs — provides checked arithmetic
## templates and numeric type conversion helpers.

import std/strformat

const
  RustPath* = "core/utils/math.rs"
  RustCrate* = "core"

type
  ArithmeticError* = object of CatchableError

template checked*(expr: untyped): untyped =
  ## Checked arithmetic expression. Raises ArithmeticError on overflow.
  try:
    expr
  except OverflowDefect:
    raise newException(ArithmeticError, "operation overflowed or result invalid")

template expected*(expr: untyped): untyped =
  ## Checked arithmetic which panics on failure. For expressions where
  ## the caller has no realistic expectation for error.
  try:
    expr
  except OverflowDefect:
    raise newException(ArithmeticError, "arithmetic expression expectation failure")

template validated*(expr: untyped): untyped =
  ## In debug mode, checked arithmetic. In release mode, unchecked for
  ## performance when the expression is obviously safe.
  when defined(release):
    expr
  else:
    expected(expr)

proc usizeFromF64*(val: float64): int =
  ## Convert a float64 to an unsigned integer.
  if val < 0.0:
    raise newException(ArithmeticError, "Converting negative float to unsigned integer")
  int(val)

proc usizeFromU64Truncated*(val: uint64): int =
  ## Truncating conversion from u64 to int.
  cast[int](val)

proc tryInto*[Src, Dst](src: Src): Dst =
  ## Checked type conversion that raises ArithmeticError on failure.
  try:
    Dst(src)
  except RangeDefect:
    raise newException(ArithmeticError,
      &"failed to convert from {$Src} to {$Dst}")

proc checkedAdd*(a, b: int64): int64 =
  ## Checked addition of two int64s.
  let r = a + b
  if (b > 0 and r < a) or (b < 0 and r > a):
    raise newException(ArithmeticError, "addition overflow")
  r

proc checkedSub*(a, b: int64): int64 =
  ## Checked subtraction of two int64s.
  let r = a - b
  if (b > 0 and r > a) or (b < 0 and r < a):
    raise newException(ArithmeticError, "subtraction overflow")
  r

proc checkedMul*(a, b: int64): int64 =
  ## Checked multiplication of two int64s.
  if a == 0 or b == 0:
    return 0
  let r = a * b
  if r div a != b:
    raise newException(ArithmeticError, "multiplication overflow")
  r

proc saturatingAdd*(a, b: uint64): uint64 =
  ## Saturating addition of two uint64s.
  if b > uint64.high - a:
    uint64.high
  else:
    a + b

proc saturatingSub*(a, b: uint64): uint64 =
  ## Saturating subtraction of two uint64s.
  if b > a: 0'u64
  else: a - b

proc clampInt*(val, lo, hi: int): int =
  ## Clamp a value to a range.
  max(lo, min(val, hi))
