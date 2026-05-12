import core/utils/math as math_utils

const
  RustPath* = "core/utils/math/expected.rs"
  RustCrate* = "core"

proc unwrapExpected[T](value: math_utils.MathResult[T]): T =
  if not value.ok:
    raise newException(OverflowDefect, "arithmetic expression expectation failure")
  value.value

proc expectedAdd*(left, right: int): int =
  math_utils.checkedAdd(left, right).unwrapExpected()

proc expectedSub*(left, right: int): int =
  math_utils.checkedSub(left, right).unwrapExpected()

proc expectedMul*(left, right: int): int =
  math_utils.checkedMul(left, right).unwrapExpected()

proc expectedDiv*(left, right: int): int =
  math_utils.checkedDiv(left, right).unwrapExpected()

proc expectedRem*(left, right: int): int =
  math_utils.checkedRem(left, right).unwrapExpected()

proc expectedAdd*(left, right: uint64): uint64 =
  math_utils.checkedAdd(left, right).unwrapExpected()

proc expectedSub*(left, right: uint64): uint64 =
  math_utils.checkedSub(left, right).unwrapExpected()

proc expectedMul*(left, right: uint64): uint64 =
  math_utils.checkedMul(left, right).unwrapExpected()

proc expectedDiv*(left, right: uint64): uint64 =
  math_utils.checkedDiv(left, right).unwrapExpected()

proc expectedRem*(left, right: uint64): uint64 =
  math_utils.checkedRem(left, right).unwrapExpected()
