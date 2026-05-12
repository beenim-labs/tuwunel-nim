import std/[options, unittest]

import core/utils/arrayvec as arrayvec_utils
import core/utils/debug as debug_utils
import core/utils/option as option_utils

suite "debug, arrayvec, and option utility parity":
  test "debug helpers truncate slices, strings, and redact optional values":
    check debug_utils.sliceTruncatedDebug([1, 2, 3], 2) == "[1, 2, \"...\"]"
    check debug_utils.sliceTruncatedDebug(["a", "b"], 2) == "[\"a\", \"b\"]"
    check debug_utils.strTruncatedDebug("abcdef", 3) == "\"abc\"..."
    check debug_utils.strTruncatedDebug("abc", 3) == "\"abc\""
    check debug_utils.redactedDebug(some("secret")) == "Some(<redacted>)"
    check debug_utils.redactedDebug(none(string)) == "None"

  test "arrayvec extendFromSlice appends and enforces capacity":
    var vec = arrayvec_utils.newArrayVec[int](3)
    discard vec.extendFromSlice([1, 2])
    check vec.len == 2
    check vec.capacity == 3
    check vec.toSeq == @[1, 2]

    discard vec.add(3)
    check vec.toSeq == @[1, 2, 3]
    expect ValueError:
      discard vec.extendFromSlice([4])

  test "option helpers map present values into optional and stream-like results":
    check some(3).mapAsync(proc(value: int): string = $value).get("") == "3"
    check none(int).mapAsync(proc(value: int): string = $value).isNone
    check some("x").mapStream(proc(value: string): string = value & value) == @["xx"]
    check none(string).mapStream(proc(value: string): string = value & value) == newSeq[string]()
