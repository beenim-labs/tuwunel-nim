## presence/mod — service module.
##
## Ported from Rust service/presence/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/presence/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: Service) =
  ## Ported from `worker`.
  discard

proc interrupt*(self: Service) =
  ## Ported from `interrupt`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc noteSync*(self: Service; userId: string) =
  ## Ported from `note_sync`.
  discard

proc lastSyncGapMs*(self: Service; userId: string): Option[uint64] =
  ## Ported from `last_sync_gap_ms`.
  none(uint64)

proc getPresence*(self: Service; userId: string): PresenceEvent =
  ## Ported from `get_presence`.
  discard

proc removePresence*(self: Service; userId: string) =
  ## Ported from `remove_presence`.
  discard

proc unsetAllPresence*(self: Service) =
  ## Ported from `unset_all_presence`.
  discard

proc presenceSince*(self: Service; since: uint64; to: Option[uint64]): impl Stream<Item = (string, uint64, [u8])> + Send + '_ =
  ## Ported from `presence_since`.
  discard

proc fromJsonBytesToEvent*(self: Service; bytes: [u8]; userId: string): PresenceEvent =
  ## Ported from `from_json_bytes_to_event`.
  discard
