## Event count / ordering — Normal and Backfilled event sequences.
##
## Ported from Rust core/matrix/pdu/count.rs — provides the Count type
## which tracks event ordering. Normal events have positive counts,
## backfilled events have negative counts. This is crucial for correct
## sync token pagination.

import std/[strutils]

const
  RustPath* = "core/matrix/pdu/count.rs"
  RustCrate* = "core"

type
  ## Direction of traversal.
  Direction* = enum
    dForward
    dBackward

  ## Count kind — normal (forward) or backfilled (backward).
  CountKind* = enum
    ckNormal
    ckBackfilled

  ## Event count for ordering — supports both normal and backfilled sequences.
  Count* = object
    case kind*: CountKind
    of ckNormal:
      value*: uint64
    of ckBackfilled:
      backValue*: int64

proc normalCount*(v: uint64): Count =
  ## Create a normal (forward) count.
  Count(kind: ckNormal, value: v)

proc backfilledCount*(v: int64): Count =
  ## Create a backfilled (negative) count.
  assert v <= 0, "Backfilled count must be non-positive"
  Count(kind: ckBackfilled, backValue: v)

proc fromSigned*(signed: int64): Count =
  ## Create a Count from a signed integer.
  if signed <= 0:
    backfilledCount(signed)
  else:
    normalCount(uint64(signed))

proc fromUnsigned*(unsigned: uint64): Count =
  ## Create a Count from an unsigned integer.
  fromSigned(int64(unsigned))

proc intoSigned*(c: Count): int64 =
  ## Convert to a signed integer.
  case c.kind
  of ckNormal: int64(c.value)
  of ckBackfilled: c.backValue

proc intoUnsigned*(c: Count): uint64 =
  ## Convert to an unsigned integer.
  case c.kind
  of ckNormal: c.value
  of ckBackfilled: uint64(c.backValue)

proc intoNormal*(c: Count): Count =
  ## Convert to a normal count (backfilled becomes 0).
  case c.kind
  of ckNormal: c
  of ckBackfilled: normalCount(0)

proc checkedAdd*(c: Count; add: uint64): Count =
  ## Add to count with overflow checking.
  case c.kind
  of ckNormal:
    let newVal = c.value + add
    if newVal < c.value:
      raise newException(OverflowDefect, "Count::Normal overflow")
    normalCount(newVal)
  of ckBackfilled:
    let newVal = c.backValue + int64(add)
    if newVal < c.backValue:
      raise newException(OverflowDefect, "Count::Backfilled overflow")
    backfilledCount(newVal)

proc checkedSub*(c: Count; sub: uint64): Count =
  ## Subtract from count with underflow checking.
  case c.kind
  of ckNormal:
    if c.value < sub:
      raise newException(OverflowDefect, "Count::Normal underflow")
    normalCount(c.value - sub)
  of ckBackfilled:
    let newVal = c.backValue - int64(sub)
    if newVal > c.backValue:
      raise newException(OverflowDefect, "Count::Backfilled underflow")
    backfilledCount(newVal)

proc checkedInc*(c: Count; dir: Direction): Count =
  ## Increment in the given direction.
  case dir
  of dForward: c.checkedAdd(1)
  of dBackward: c.checkedSub(1)

proc saturatingAdd*(c: Count; add: uint64): Count =
  ## Add with saturation (no overflow).
  case c.kind
  of ckNormal:
    if add > uint64.high - c.value:
      normalCount(uint64.high)
    else:
      normalCount(c.value + add)
  of ckBackfilled:
    let maxAdd = int64(0) - c.backValue  # max we can add to stay <= 0
    if int64(add) > maxAdd or add > uint64(int64.high):
      backfilledCount(0)
    else:
      backfilledCount(c.backValue + int64(add))

proc saturatingSub*(c: Count; sub: uint64): Count =
  ## Subtract with saturation (no underflow).
  case c.kind
  of ckNormal:
    if c.value < sub: normalCount(0)
    else: normalCount(c.value - sub)
  of ckBackfilled: backfilledCount(max(c.backValue - int64(sub), int64.low))

proc saturatingInc*(c: Count; dir: Direction): Count =
  ## Increment with saturation.
  case dir
  of dForward: c.saturatingAdd(1)
  of dBackward: c.saturatingSub(1)

proc minCount*(): Count =
  ## Minimum possible count.
  backfilledCount(int64.low)

proc maxCount*(): Count =
  ## Maximum possible count.
  normalCount(uint64(int64.high))

proc defaultCount*(): Count =
  ## Default count (Normal 0).
  normalCount(0)

proc `<`*(a, b: Count): bool =
  a.intoSigned() < b.intoSigned()

proc `<=`*(a, b: Count): bool =
  a.intoSigned() <= b.intoSigned()

proc `==`*(a, b: Count): bool =
  a.intoSigned() == b.intoSigned()

proc cmp*(a, b: Count): int =
  cmp(a.intoSigned(), b.intoSigned())

proc `$`*(c: Count): string =
  case c.kind
  of ckNormal: $c.value
  of ckBackfilled: $c.backValue

proc parseCount*(s: string): Count =
  ## Parse a Count from a string.
  fromSigned(parseBiggestInt(s))
