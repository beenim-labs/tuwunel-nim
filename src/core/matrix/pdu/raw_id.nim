const
  RustPath* = "core/matrix/pdu/raw_id.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import core/matrix/pdu/[count, id]

const
  IntLen* = 8
  RawIdNormalLen* = 16
  RawIdBackfilledLen* = 24

type
  RawId* = object
    bytes*: seq[byte]

proc beBytes(value: uint64): seq[byte] =
  result = newSeq[byte](8)
  for idx in 0 ..< 8:
    result[idx] = byte((value shr ((7 - idx) * 8)) and 0xff'u64)

proc uint64FromBe(bytes: openArray[byte]): uint64 =
  result = 0'u64
  for b in bytes:
    result = (result shl 8) or uint64(b)

proc rawId*(idValue: PduId): RawId =
  result = RawId(bytes: @[])
  result.bytes.add(beBytes(idValue.shortRoomId))
  case idValue.count.kind
  of pckNormal:
    result.bytes.add(beBytes(idValue.count.normal))
  of pckBackfilled:
    result.bytes.add(beBytes(0'u64))
    result.bytes.add(beBytes(idValue.count.intoUnsigned()))

proc rawIdFromBytes*(bytes: openArray[byte]): tuple[ok: bool, rawId: RawId, message: string] =
  if bytes.len notin [RawIdNormalLen, RawIdBackfilledLen]:
    return (false, RawId(), "unrecognized RawId length")
  result = (true, RawId(bytes: @[]), "")
  for b in bytes:
    result.rawId.bytes.add(b)

proc isBackfilled*(raw: RawId): bool =
  raw.bytes.len == RawIdBackfilledLen

proc asBytes*(raw: RawId): seq[byte] =
  raw.bytes

proc shortRoomIdBytes*(raw: RawId): seq[byte] =
  if raw.bytes.len < IntLen:
    return @[]
  raw.bytes[0 ..< IntLen]

proc countBytes*(raw: RawId): seq[byte] =
  if raw.bytes.len == RawIdNormalLen:
    raw.bytes[IntLen ..< IntLen * 2]
  elif raw.bytes.len == RawIdBackfilledLen:
    raw.bytes[IntLen * 2 ..< IntLen * 3]
  else:
    @[]

proc pduCount*(raw: RawId): PduCount =
  count.fromUnsigned(uint64FromBe(raw.countBytes()))

proc toPduId*(raw: RawId): PduId =
  pduId(uint64FromBe(raw.shortRoomIdBytes()), raw.pduCount())

proc isRoomEq*(a, b: RawId): bool =
  a.shortRoomIdBytes() == b.shortRoomIdBytes()
