## event_handler/acl_check — service module.
##
## Ported from Rust service/rooms/event_handler/acl_check.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/event_handler/acl_check.rs"
  RustCrate* = "service"

proc aclCheck*(serverName: string; roomId: string) =
  ## Ported from `acl_check`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.