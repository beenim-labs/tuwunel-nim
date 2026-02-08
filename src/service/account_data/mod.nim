## account_data/mod — service module.
##
## Ported from Rust service/account_data/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/account_data/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc update*(self: Service; roomId: Option[string]; userId: string; eventType: RoomAccountDataEventType; data: serde_json::Value) =
  ## Ported from `update`.
  discard

proc getRaw*(self: Service; roomId: Option[string]; userId: string; kind: string): Handle<'_> =
  ## Ported from `get_raw`.
  discard
