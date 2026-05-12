import std/unittest

import "core/utils/defer" as defer_utils

suite "defer utility parity":
  test "defer guard runs action when scope exits":
    var called = false
    block:
      var guard = defer_utils.newDeferGuard(proc() =
        called = true
      )
      discard guard
      check not called
    check called

  test "dismiss prevents deferred action and runNow is single-shot":
    var count = 0
    block:
      var guard = defer_utils.newDeferGuard(proc() =
        inc count
      )
      guard.dismiss()
    check count == 0

    block:
      var guard = defer_utils.newDeferGuard(proc() =
        inc count
      )
      guard.runNow()
      check count == 1
    check count == 1

  test "scopeRestore restores prior value after body":
    var value = "old"
    defer_utils.scopeRestore(value, "new"):
      check value == "new"
    check value == "old"
