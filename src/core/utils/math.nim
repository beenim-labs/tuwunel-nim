const
  RustPath* = "core/utils/math.rs"
  RustCrate* = "core"
  RumaUIntMax* = 9_007_199_254_740_991'u64

type MathResult*[T] = tuple[ok: bool, value: T, message: string]

proc arithmeticError*[T](value: T): MathResult[T] =
  (false, value, "operation overflowed or result invalid")

proc checkedAdd*(left, right: int): MathResult[int] =
  if (right > 0 and left > high(int) - right) or
      (right < 0 and left < low(int) - right):
    return arithmeticError(0)
  (true, left + right, "")

proc checkedSub*(left, right: int): MathResult[int] =
  if (right < 0 and left > high(int) + right) or
      (right > 0 and left < low(int) + right):
    return arithmeticError(0)
  (true, left - right, "")

proc checkedMul*(left, right: int): MathResult[int] =
  if left == 0 or right == 0:
    return (true, 0, "")
  let overflow =
    if left > 0:
      if right > 0: left > high(int) div right
      else: right < low(int) div left
    else:
      if right > 0: left < low(int) div right
      else: right < high(int) div left
  if overflow:
    return arithmeticError(0)
  (true, left * right, "")

proc checkedDiv*(left, right: int): MathResult[int] =
  if right == 0 or (left == low(int) and right == -1):
    return arithmeticError(0)
  (true, left div right, "")

proc checkedRem*(left, right: int): MathResult[int] =
  if right == 0 or (left == low(int) and right == -1):
    return arithmeticError(0)
  (true, left mod right, "")

proc checkedAdd*(left, right: uint64): MathResult[uint64] =
  if left > high(uint64) - right:
    return arithmeticError(0'u64)
  (true, left + right, "")

proc checkedSub*(left, right: uint64): MathResult[uint64] =
  if left < right:
    return arithmeticError(0'u64)
  (true, left - right, "")

proc checkedMul*(left, right: uint64): MathResult[uint64] =
  if left != 0'u64 and right > high(uint64) div left:
    return arithmeticError(0'u64)
  (true, left * right, "")

proc checkedDiv*(left, right: uint64): MathResult[uint64] =
  if right == 0'u64:
    return arithmeticError(0'u64)
  (true, left div right, "")

proc checkedRem*(left, right: uint64): MathResult[uint64] =
  if right == 0'u64:
    return arithmeticError(0'u64)
  (true, left mod right, "")

proc usizeFromF64*(value: float): MathResult[int] =
  if value < 0.0 or value != value or value > float(high(int)):
    return (false, 0, "Converting negative float to unsigned integer")
  (true, int(value), "")

proc usizeFromRuma*(value: uint64): int =
  if value > uint64(high(int)):
    raise newException(OverflowDefect, "failed conversion from ruma::UInt to usize")
  int(value)

proc rumaFromU64*(value: uint64): uint64 =
  if value > RumaUIntMax:
    raise newException(OverflowDefect, "failed conversion from u64 to ruma::UInt")
  value

proc rumaFromUsize*(value: int): uint64 =
  if value < 0 or uint64(value) > RumaUIntMax:
    raise newException(OverflowDefect, "failed conversion from usize to ruma::UInt")
  uint64(value)

proc usizeFromU64Truncated*(value: uint64): int =
  int(value)

proc tryIntoInt*(value: uint64): MathResult[int] =
  if value > uint64(high(int)):
    return (false, 0, "failed to convert from u64 to int")
  (true, int(value), "")

proc expectIntoInt*(value: uint64): int =
  let converted = tryIntoInt(value)
  if not converted.ok:
    raise newException(OverflowDefect, "failed conversion from Src to Dst")
  converted.value
