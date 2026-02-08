## presence/data — service module.
##
## Ported from Rust service/presence/data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/presence/data.rs"
  RustCrate* = "service"

proc getPresence*(userId: string): (uint64 =
  ## Ported from `get_presence`.
  discard

proc getPresenceRaw*(userId: string): (uint64 =
  ## Ported from `get_presence_raw`.
  discard

proc setPresence*(userId: string; presenceState: PresenceState; currentlyActive: Option[bool]; lastActiveAgo: Option[UInt]; statusMsg: Option[string]): Option[uint64] =
  ## Ported from `set_presence`.
  none(uint64)

proc removePresence*(userId: string) =
  ## Ported from `remove_presence`.
  discard

proc presenceSince*(since: uint64; to: Option[uint64]): impl Stream<Item = (string, uint64, [u8])> + Send + '_ =
  ## Ported from `presence_since`.
  discard

proc presenceidKey*(count: uint64; userId: string): seq[u8] =
  ## Ported from `presenceid_key`.
  @[]

proc presenceidParse*(key: [u8]): (uint64 =
  ## Ported from `presenceid_parse`.
  discard

proc userIdFromBytes*(bytes: [u8]): string =
  ## Ported from `user_id_from_bytes`.
  ""
