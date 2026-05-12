import std/unittest

import core/utils/math as math_utils
import core/utils/math/expected as expected_utils
import core/utils/math/tried as tried_utils

suite "math utility parity":
  test "checked arithmetic returns Result-shaped tuples":
    check math_utils.checkedAdd(2, 3).value == 5
    check not math_utils.checkedAdd(high(int), 1).ok
    check math_utils.checkedSub(2, 3).value == -1
    check not math_utils.checkedMul(high(int), 2).ok
    check not math_utils.checkedDiv(1, 0).ok
    check math_utils.checkedRem(5, 2).value == 1

    check math_utils.checkedAdd(high(uint64), 0'u64).ok
    check not math_utils.checkedAdd(high(uint64), 1'u64).ok
    check not math_utils.checkedSub(0'u64, 1'u64).ok

  test "expected helpers panic on invalid arithmetic":
    check expected_utils.expectedAdd(4, 5) == 9
    check expected_utils.expectedMul(6'u64, 7'u64) == 42'u64
    expect OverflowDefect:
      discard expected_utils.expectedDiv(1, 0)

  test "tried helpers preserve operation-specific failures":
    check tried_utils.tryAdd(1, 2).value == 3
    check not tried_utils.trySub(0'u64, 1'u64).ok
    check not tried_utils.tryRem(10, 0).ok

  test "conversion helpers follow usize and ruma constraints":
    check math_utils.usizeFromF64(3.8).value == 3
    check not math_utils.usizeFromF64(-1.0).ok
    check math_utils.rumaFromU64(math_utils.RumaUIntMax) == math_utils.RumaUIntMax
    expect OverflowDefect:
      discard math_utils.rumaFromU64(math_utils.RumaUIntMax + 1'u64)
    check math_utils.expectIntoInt(42'u64) == 42
