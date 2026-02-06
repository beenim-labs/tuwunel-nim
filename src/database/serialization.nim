## Serialization helpers modeled after tuwunel's database serializer rules.
##
## Scope in this milestone:
## - byte/record framing with 0xFF separator
## - fixed-width integer big-endian encoding/decoding
## - tuple-style record packing helpers

import types

proc toByteSeq*(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i, c in s:
    result[i] = byte(ord(c))

proc fromByteSeq*(b: openArray[byte]): string =
  result = newString(b.len)
  for i, v in b:
    result[i] = char(v)

proc encodeU64BE*(v: uint64): seq[byte] =
  result = newSeq[byte](8)
  for i in 0 ..< 8:
    let shift = uint((7 - i) * 8)
    result[i] = byte((v shr shift) and 0xFF'u64)

proc decodeU64BE*(data: openArray[byte]): uint64 =
  if data.len != 8:
    raise newDbError("decodeU64BE requires exactly 8 bytes")

  result = 0'u64
  for i in 0 ..< 8:
    result = (result shl 8) or uint64(data[i])

proc encodeI64BE*(v: int64): seq[byte] =
  encodeU64BE(cast[uint64](v))

proc decodeI64BE*(data: openArray[byte]): int64 =
  cast[int64](decodeU64BE(data))

proc encodeU32BE*(v: uint32): seq[byte] =
  result = newSeq[byte](4)
  for i in 0 ..< 4:
    let shift = uint((3 - i) * 8)
    result[i] = byte((v shr shift) and 0xFF'u32)

proc decodeU32BE*(data: openArray[byte]): uint32 =
  if data.len != 4:
    raise newDbError("decodeU32BE requires exactly 4 bytes")

  result = 0'u32
  for i in 0 ..< 4:
    result = (result shl 8) or uint32(data[i])

proc serializeRecords*(records: openArray[seq[byte]]): seq[byte] =
  ## Pack sequence records separated by 0xFF, matching DB tuple framing.
  if records.len == 0:
    return @[]

  var total = 0
  for i, r in records:
    total += r.len
    if i > 0:
      inc total

  result = newSeq[byte](total)
  var pos = 0
  for i, r in records:
    if i > 0:
      result[pos] = Sep
      inc pos
    for b in r:
      result[pos] = b
      inc pos

proc splitRecords*(payload: openArray[byte]): seq[seq[byte]] =
  ## Split tuple framing into records by separator.
  result = @[]
  var current: seq[byte] = @[]
  for b in payload:
    if b == Sep:
      result.add(current)
      current = @[]
    else:
      current.add(b)
  result.add(current)

proc serializeTuple2*(a, b: seq[byte]): seq[byte] =
  serializeRecords([a, b])

proc serializeTuple3*(a, b, c: seq[byte]): seq[byte] =
  serializeRecords([a, b, c])

proc serializeStringAndU64*(s: string; v: uint64): seq[byte] =
  serializeTuple2(toByteSeq(s), encodeU64BE(v))

proc hasSeparator*(payload: openArray[byte]): bool =
  for b in payload:
    if b == Sep:
      return true
  false

proc countSeparators*(payload: openArray[byte]): int =
  result = 0
  for b in payload:
    if b == Sep:
      inc result
