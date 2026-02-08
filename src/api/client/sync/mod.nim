## sync/mod — api module.
##
## Ported from Rust api/client/sync/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/mod.rs"
  RustCrate* = "api"

proc loadTimeline*(services: Services; senderUser: string; roomId: string; roomsincecount: PduCount; nextBatch: Option[PduCount]; limit: int): (seq[(PduCount, bool, PduCount), Error] =
  ## Ported from `load_timeline`.
  discard

proc shareEncryptedRoom*(services: Services; senderUser: string; userId: string; ignoreRoom: Option[string]): bool =
  ## Ported from `share_encrypted_room`.
  false
