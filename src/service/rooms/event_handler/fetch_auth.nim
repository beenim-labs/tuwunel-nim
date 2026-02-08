## event_handler/fetch_auth — service module.
##
## Ported from Rust service/rooms/event_handler/fetch_auth.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/fetch_auth.rs"
  RustCrate* = "service"

proc fetchAuthChain*(origin: string; RoomId: string; eventId: string; roomVersion: RoomVersionId): (string, Option[PduEvent], seq[(string, CanonicalJsonObject)]) =
  ## Ported from `fetch_auth_chain`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.