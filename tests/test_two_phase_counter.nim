import std/unittest

import core/utils/two_phase_counter

suite "two phase counter parity":
  test "new counter starts retired and dispatched at init":
    let counter = newCounter(7'u64)
    check counter.current() == 7'u64
    check counter.dispatched() == 7'u64
    check counter.range() == (start: 7'u64, stop: 7'u64)

  test "dispatch commits ids and keeps pending ids out of current":
    var committed: seq[uint64] = @[]
    let counter = newCounter(
      41'u64,
      proc(value: uint64): tuple[ok: bool, message: string] =
        committed.add(value)
        (true, ""),
    )

    let first = counter.next()
    check first.ok
    check first.permit.id() == 42'u64
    check first.permit.retired() == 41'u64
    check counter.current() == 41'u64
    check counter.dispatched() == 42'u64
    check committed == @[42'u64]

    let second = counter.next()
    check second.ok
    check second.permit.id() == 43'u64
    check second.permit.retired() == 41'u64
    check counter.range() == (start: 41'u64, stop: 43'u64)

  test "retiring permits releases only when the oldest pending id retires":
    var released: seq[uint64] = @[]
    let counter = newCounter(
      0'u64,
      release = proc(value: uint64): tuple[ok: bool, message: string] =
        released.add(value)
        (true, ""),
    )

    let first = counter.next().permit
    let second = counter.next().permit

    check second.retire().ok
    check released.len == 0
    check counter.current() == 0'u64

    check first.retire().ok
    check released == @[2'u64]
    check counter.current() == 2'u64
    check not first.retire().ok

  test "overflow and callback errors are exposed as failed dispatches":
    let overflow = newCounter(high(uint64))
    check not overflow.next().ok

    let counter = newCounter(
      0'u64,
      proc(value: uint64): tuple[ok: bool, message: string] =
        discard value
        (false, "commit failed"),
    )
    let permit = counter.next()
    check not permit.ok
    check permit.message == "commit failed"
    check counter.current() == 0'u64
    check counter.dispatched() == 0'u64
