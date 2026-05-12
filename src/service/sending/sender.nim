const
  RustPath* = "service/sending/sender.rs"
  RustCrate* = "service"

import std/[options, tables]

import core/utils/time/exponential_backoff
import service/sending/[data, dest]

const
  PDU_LIMIT* = 50
  EDU_LIMIT* = 100
  DEQUEUE_LIMIT* = 48

type
  TransactionStatusKind* = enum
    tskRunning,
    tskFailed,
    tskRetrying

  TransactionStatus* = object
    kind*: TransactionStatusKind
    tries*: uint32
    failedAtMs*: uint64

  SelectCurrentResult* = tuple[allow: bool, retry: bool]

  SendingSelector* = object
    statuses*: Table[string, TransactionStatus]
    senderTimeoutSecs*: uint64
    senderRetryBackoffLimitSecs*: uint64

proc initSendingSelector*(
  senderTimeoutSecs = 180'u64;
  senderRetryBackoffLimitSecs = 86_400'u64;
): SendingSelector =
  SendingSelector(
    statuses: initTable[string, TransactionStatus](),
    senderTimeoutSecs: senderTimeoutSecs,
    senderRetryBackoffLimitSecs: senderRetryBackoffLimitSecs,
  )

proc runningStatus*(): TransactionStatus =
  TransactionStatus(kind: tskRunning)

proc failedStatus*(tries: uint32; failedAtMs: uint64): TransactionStatus =
  TransactionStatus(kind: tskFailed, tries: tries, failedAtMs: failedAtMs)

proc retryingStatus*(tries: uint32): TransactionStatus =
  TransactionStatus(kind: tskRetrying, tries: tries)

proc statusKey*(dest: Destination): string =
  dest.destinationId()

proc markFailed*(selector: var SendingSelector; dest: Destination; nowMs: uint64) =
  let key = statusKey(dest)
  let current = selector.statuses.getOrDefault(key, runningStatus())
  case current.kind
  of tskRunning:
    selector.statuses[key] = failedStatus(1'u32, nowMs)
  of tskRetrying:
    selector.statuses[key] = failedStatus(current.tries + 1'u32, nowMs)
  of tskFailed:
    selector.statuses[key] = current

proc markSuccess*(selector: var SendingSelector; dest: Destination) =
  selector.statuses.del(statusKey(dest))

proc selectEventsCurrent*(
  selector: var SendingSelector;
  dest: Destination;
  nowMs: uint64;
): SelectCurrentResult =
  let key = statusKey(dest)
  if key notin selector.statuses:
    selector.statuses[key] = runningStatus()
    return (true, false)

  let current = selector.statuses[key]
  case current.kind
  of tskFailed:
    let elapsedSecs =
      if nowMs <= current.failedAtMs:
        0'u64
      else:
        (nowMs - current.failedAtMs) div 1_000'u64
    if dest.kind != dkAppservice and continueExponentialBackoffSecs(
      selector.senderTimeoutSecs,
      selector.senderRetryBackoffLimitSecs,
      elapsedSecs,
      current.tries,
    ):
      return (false, false)
    selector.statuses[key] = retryingStatus(current.tries)
    (true, true)
  of tskRunning, tskRetrying:
    (false, false)

proc selectEvents*(
  selector: var SendingSelector;
  store: var SendingData;
  dest: Destination;
  newEvents: openArray[QueueItem];
  nowMs: uint64;
): Option[seq[SendingEvent]] =
  let current = selector.selectEventsCurrent(dest, nowMs)
  if not current.allow:
    return none(seq[SendingEvent])

  var events: seq[SendingEvent] = @[]
  if current.retry:
    for item in store.activeRequestsFor(dest):
      events.add(item.event)
    return some(events)

  store.markAsActive(newEvents)
  for item in newEvents:
    events.add(item.event)
  some(events)

proc finishResponseOk*(
  selector: var SendingSelector;
  store: var SendingData;
  dest: Destination;
): seq[QueueItem] =
  discard store.deleteAllActiveRequestsFor(dest)
  result = store.queuedRequests(dest, DEQUEUE_LIMIT)
  if result.len == 0:
    selector.markSuccess(dest)
  else:
    store.markAsActive(result)
