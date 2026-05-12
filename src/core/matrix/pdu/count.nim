const
  RustPath* = "core/matrix/pdu/count.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/strutils

type
  PduCountKind* = enum
    pckNormal,
    pckBackfilled

  PduCount* = object
    case kind*: PduCountKind
    of pckNormal:
      normal*: uint64
    of pckBackfilled:
      backfilled*: int64

const SignBit = 1'u64 shl 63

proc signedFromUnsigned(unsigned: uint64): int64 =
  if unsigned <= uint64(high(int64)):
    int64(unsigned)
  else:
    let magnitude = (not unsigned) + 1'u64
    if magnitude == SignBit:
      low(int64)
    else:
      -int64(magnitude)

proc unsignedFromSigned(signed: int64): uint64 =
  if signed >= 0:
    uint64(signed)
  elif signed == low(int64):
    SignBit
  else:
    (not uint64(-signed)) + 1'u64

proc normalCount*(value: uint64): PduCount =
  PduCount(kind: pckNormal, normal: value)

proc backfilledCount*(value: int64): PduCount =
  PduCount(kind: pckBackfilled, backfilled: min(value, 0'i64))

proc fromSigned*(signed: int64): PduCount =
  if signed <= 0:
    backfilledCount(signed)
  else:
    normalCount(uint64(signed))

proc fromUnsigned*(unsigned: uint64): PduCount =
  fromSigned(signedFromUnsigned(unsigned))

proc parsePduCount*(token: string): tuple[ok: bool, count: PduCount, message: string] =
  try:
    (true, fromSigned(parseBiggestInt(token).int64), "")
  except ValueError as err:
    (false, normalCount(0), err.msg)

proc intoSigned*(count: PduCount): int64 =
  case count.kind
  of pckNormal:
    if count.normal > uint64(high(int64)): high(int64) else: int64(count.normal)
  of pckBackfilled:
    count.backfilled

proc intoUnsigned*(count: PduCount): uint64 =
  case count.kind
  of pckNormal:
    count.normal
  of pckBackfilled:
    unsignedFromSigned(count.backfilled)

proc intoNormal*(count: PduCount): PduCount =
  case count.kind
  of pckNormal:
    count
  of pckBackfilled:
    normalCount(0)

proc checkedAdd*(count: PduCount; value: uint64): tuple[ok: bool, count: PduCount, message: string] =
  case count.kind
  of pckNormal:
    if value > high(uint64) - count.normal:
      return (false, count, "Count::Normal overflow")
    (true, normalCount(count.normal + value), "")
  of pckBackfilled:
    if value > uint64(high(int64)):
      return (false, count, "Count::Backfilled overflow")
    let addend = int64(value)
    if count.backfilled > high(int64) - addend:
      return (false, count, "Count::Backfilled overflow")
    (true, backfilledCount(count.backfilled + addend), "")

proc checkedSub*(count: PduCount; value: uint64): tuple[ok: bool, count: PduCount, message: string] =
  case count.kind
  of pckNormal:
    if value > count.normal:
      return (false, count, "Count::Normal underflow")
    (true, normalCount(count.normal - value), "")
  of pckBackfilled:
    if value > uint64(high(int64)):
      return (false, count, "Count::Backfilled underflow")
    let subtrahend = int64(value)
    if count.backfilled < low(int64) + subtrahend:
      return (false, count, "Count::Backfilled underflow")
    (true, backfilledCount(count.backfilled - subtrahend), "")

proc saturatingAdd*(count: PduCount; value: uint64): PduCount =
  let checked = checkedAdd(count, value)
  if checked.ok:
    checked.count
  elif count.kind == pckNormal:
    normalCount(high(uint64))
  else:
    backfilledCount(high(int64))

proc saturatingSub*(count: PduCount; value: uint64): PduCount =
  let checked = checkedSub(count, value)
  if checked.ok:
    checked.count
  elif count.kind == pckNormal:
    normalCount(0)
  else:
    backfilledCount(low(int64))

proc minCount*(): PduCount =
  backfilledCount(low(int64))

proc maxCount*(): PduCount =
  normalCount(uint64(high(int64)))

proc `$`*(count: PduCount): string =
  $count.intoSigned()

proc cmp*(a, b: PduCount): int =
  system.cmp(a.intoSigned(), b.intoSigned())
