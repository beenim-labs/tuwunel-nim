## PDU ID types — internal event identifiers.
##
## Ported from Rust core/matrix/pdu/id.rs — provides the PduId type
## combining a short room ID with a count for compact event addressing.

import count

const
  RustPath* = "core/matrix/pdu/id.rs"
  RustCrate* = "core"

type
  ## Short room identifier (internal database key).
  ShortRoomId* = uint64

  ## Compact PDU identifier: (short_room_id, count).
  PduId* = object
    shortroomid*: ShortRoomId
    count*: Count

proc newPduId*(shortroomid: ShortRoomId; count: Count): PduId =
  ## Create a new PduId.
  PduId(shortroomid: shortroomid, count: count)

proc toBeBytes*(id: PduId): seq[uint8] =
  ## Serialize the PduId to big-endian bytes (16 bytes total).
  result = newSeq[uint8](16)
  let roomBytes = id.shortroomid.toBytesBE()
  let countBytes = id.count.intoUnsigned().toBytesBE()
  for i in 0..7:
    result[i] = roomBytes[i]
  for i in 0..7:
    result[i + 8] = countBytes[i]

proc toBytesBE*(v: uint64): array[8, uint8] =
  ## Convert uint64 to big-endian byte array.
  result[0] = uint8((v shr 56) and 0xFF)
  result[1] = uint8((v shr 48) and 0xFF)
  result[2] = uint8((v shr 40) and 0xFF)
  result[3] = uint8((v shr 32) and 0xFF)
  result[4] = uint8((v shr 24) and 0xFF)
  result[5] = uint8((v shr 16) and 0xFF)
  result[6] = uint8((v shr 8) and 0xFF)
  result[7] = uint8(v and 0xFF)

proc `$`*(id: PduId): string =
  $id.shortroomid & ":" & $id.count
