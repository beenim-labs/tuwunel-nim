## presence/presence — service module.
##
## Ported from Rust service/presence/presence.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/presence/presence.rs"
  RustCrate* = "service"

proc fromJsonBytes*(bytes: [u8]) =
  ## Ported from `from_json_bytes`.
  discard

proc state*(): PresenceState =
  ## Ported from `state`.
  discard

proc lastActiveTs*(): uint64 =
  ## Ported from `last_active_ts`.
  0

proc statusMsg*(): Option[string] =
  ## Ported from `status_msg`.
  none(string)

proc toPresenceEvent*(userId: string; users: users::Service): PresenceEvent =
  ## Ported from `to_presence_event`.
  discard
