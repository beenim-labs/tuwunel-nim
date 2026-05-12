import core/utils/math as math_utils

const
  RustPath* = "core/utils/math/tried.rs"
  RustCrate* = "core"

proc tryAdd*(left, right: int): math_utils.MathResult[int] =
  math_utils.checkedAdd(left, right)

proc trySub*(left, right: int): math_utils.MathResult[int] =
  math_utils.checkedSub(left, right)

proc tryMul*(left, right: int): math_utils.MathResult[int] =
  math_utils.checkedMul(left, right)

proc tryDiv*(left, right: int): math_utils.MathResult[int] =
  math_utils.checkedDiv(left, right)

proc tryRem*(left, right: int): math_utils.MathResult[int] =
  math_utils.checkedRem(left, right)

proc tryAdd*(left, right: uint64): math_utils.MathResult[uint64] =
  math_utils.checkedAdd(left, right)

proc trySub*(left, right: uint64): math_utils.MathResult[uint64] =
  math_utils.checkedSub(left, right)

proc tryMul*(left, right: uint64): math_utils.MathResult[uint64] =
  math_utils.checkedMul(left, right)

proc tryDiv*(left, right: uint64): math_utils.MathResult[uint64] =
  math_utils.checkedDiv(left, right)

proc tryRem*(left, right: uint64): math_utils.MathResult[uint64] =
  math_utils.checkedRem(left, right)
