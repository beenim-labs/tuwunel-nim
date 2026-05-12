const
  RustPath* = "core/matrix/pdu/id.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import core/matrix/pdu/count

type
  ShortId* = uint64
  ShortRoomId* = uint64
  PduId* = object
    shortRoomId*: ShortRoomId
    count*: PduCount

proc pduId*(shortRoomId: ShortRoomId; count: PduCount): PduId =
  PduId(shortRoomId: shortRoomId, count: count)
