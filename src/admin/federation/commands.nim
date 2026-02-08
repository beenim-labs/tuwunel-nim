## federation/commands — admin module.
##
## Ported from Rust admin/federation/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/federation/commands.rs"
  RustCrate* = "admin"

proc disableRoom*(roomId: string) =
  ## Ported from `disable_room`.
  discard

proc enableRoom*(roomId: string) =
  ## Ported from `enable_room`.
  discard

proc incomingFederation*() =
  ## Ported from `incoming_federation`.
  discard

proc fetchSupportWellKnown*(serverName: string) =
  ## Ported from `fetch_support_well_known`.
  discard

proc remoteUserInRooms*(userId: string) =
  ## Ported from `remote_user_in_rooms`.
  discard
