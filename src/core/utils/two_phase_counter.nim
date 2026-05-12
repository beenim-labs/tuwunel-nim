const
  RustPath* = "core/utils/two_phase_counter.rs"
  RustCrate* = "core"

type
  CounterCallback* = proc(value: uint64): tuple[ok: bool, message: string] {.closure.}

  Counter* = ref object
    dispatchedValue: uint64
    pending: seq[uint64]
    commit: CounterCallback
    release: CounterCallback

  Permit* = ref object
    counter: Counter
    retiredValue: uint64
    sequenceId: uint64
    active: bool

proc okCallback(value: uint64): tuple[ok: bool, message: string] =
  discard value
  (true, "")

proc retiredLocked(counter: Counter): uint64 =
  if counter.pending.len == 0:
    return counter.dispatchedValue
  if counter.pending[0] == 0'u64:
    0'u64
  else:
    counter.pending[0] - 1'u64

proc pendingIndex(counter: Counter; id: uint64): int =
  for idx, value in counter.pending:
    if value == id:
      return idx
  -1

proc newCounter*(
  init: uint64;
  commit: CounterCallback = okCallback;
  release: CounterCallback = okCallback;
): Counter =
  Counter(
    dispatchedValue: init,
    pending: @[],
    commit: commit,
    release: release,
  )

proc next*(counter: Counter): tuple[ok: bool, permit: Permit, message: string] =
  if counter.dispatchedValue == high(uint64):
    return (false, nil, "operation overflowed or result invalid")

  let retired = counter.retiredLocked()
  let dispatched = counter.dispatchedValue + 1'u64
  if counter.pendingIndex(dispatched) >= 0:
    return (false, nil, "sequence number cannot already be pending")

  let committed = counter.commit(dispatched)
  if not committed.ok:
    return (false, nil, committed.message)

  counter.dispatchedValue = dispatched
  counter.pending.add(dispatched)
  (true, Permit(
    counter: counter,
    retiredValue: retired,
    sequenceId: dispatched,
    active: true,
  ), "")

proc range*(counter: Counter): tuple[start: uint64, stop: uint64] =
  (counter.retiredLocked(), counter.dispatchedValue)

proc current*(counter: Counter): uint64 =
  counter.retiredLocked()

proc dispatched*(counter: Counter): uint64 =
  counter.dispatchedValue

proc retired*(permit: Permit): uint64 =
  permit.retiredValue

proc id*(permit: Permit): uint64 =
  permit.sequenceId

proc retire*(permit: Permit): tuple[ok: bool, message: string] =
  if permit.isNil or not permit.active:
    return (false, "permit is not active")

  let counter = permit.counter
  let index = counter.pendingIndex(permit.sequenceId)
  if index < 0:
    permit.active = false
    return (false, "sequence number must be currently pending")

  counter.pending.delete(index)
  permit.active = false
  if index != 0:
    return (true, "")

  let releaseValue =
    if counter.pending.len == 0:
      counter.dispatchedValue
    else:
      permit.sequenceId
  let released = counter.release(releaseValue)
  if not released.ok:
    return (false, released.message)
  (true, "")

proc close*(permit: Permit): tuple[ok: bool, message: string] =
  retire(permit)
