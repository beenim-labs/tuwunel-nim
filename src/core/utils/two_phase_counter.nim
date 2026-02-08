import std/[deques, locks]

const
  RustPath* = "core/utils/two_phase_counter.rs"
  RustCrate* = "core"

type
  CommitCallback* = proc(id: uint64) {.gcsafe.}

  TwoPhaseCounter* = ref object
    ## Two-Phase Counter with pending write tracking.
    lock: Lock
    dispatched: uint64
    pending: Deque[uint64]
    commitCb: CommitCallback
    releaseCb: CommitCallback

  CounterPermit* = ref object
    ## RAII permit — holds a sequence number and retires it on destruction.
    counter: TwoPhaseCounter
    retiredVal: uint64
    idVal: uint64

proc newTwoPhaseCounter*(init: uint64;
    commit: CommitCallback;
    release: CommitCallback): TwoPhaseCounter =
  ## Construct a new Two-Phase counter. The value of `init` is considered
  ## retired; the next sequence dispatched will be init + 1.
  result = TwoPhaseCounter(
    dispatched: init,
    pending: initDeque[uint64](),
    commitCb: commit,
    releaseCb: release,
  )
  initLock(result.lock)

proc retired*(c: TwoPhaseCounter): uint64 =
  ## Calculate the retired sequence number — one less than the lowest
  ## pending number. If nothing is pending, dispatched is returned.
  if c.pending.len > 0:
    c.pending.peekFirst() - 1
  else:
    c.dispatched

proc current*(c: TwoPhaseCounter): uint64 =
  ## Load the highest sequence number safe for reading.
  acquire(c.lock)
  result = c.retired()
  release(c.lock)

proc dispatched*(c: TwoPhaseCounter): uint64 =
  ## Load the highest dispatched sequence number (may be pending).
  acquire(c.lock)
  result = c.dispatched
  release(c.lock)

proc rangeValues*(c: TwoPhaseCounter): (uint64, uint64) =
  ## Load the current and dispatched values simultaneously.
  acquire(c.lock)
  result = (c.retired(), c.dispatched)
  release(c.lock)

proc next*(c: TwoPhaseCounter): CounterPermit =
  ## Obtain the next sequence number as a permit.
  acquire(c.lock)
  let retiredNow = c.retired()
  c.dispatched += 1
  let id = c.dispatched
  c.commitCb(id)
  c.pending.addLast(id)
  release(c.lock)
  CounterPermit(counter: c, retiredVal: retiredNow, idVal: id)

proc retire*(c: TwoPhaseCounter; id: uint64) =
  ## Retire a sequence number, removing it from pending.
  acquire(c.lock)
  # Find index and rebuild deque without the retired element
  var idx = -1
  for i in 0 ..< c.pending.len:
    if c.pending[i] == id:
      idx = i
      break
  if idx >= 0:
    # Rebuild deque without the element at idx
    var newPending = initDeque[uint64](c.pending.len)
    for i in 0 ..< c.pending.len:
      if i != idx:
        newPending.addLast(c.pending[i])
    c.pending = newPending
    # Release occurs only when the oldest value retires
    if idx == 0:
      let releaseVal = if c.pending.len == 0: c.dispatched else: id
      c.releaseCb(releaseVal)
  release(c.lock)

proc id*(p: CounterPermit): uint64 = p.idVal
proc retiredAt*(p: CounterPermit): uint64 = p.retiredVal

proc release*(p: CounterPermit) =
  ## Manually release the permit (retire the sequence number).
  if p.counter != nil:
    p.counter.retire(p.idVal)
