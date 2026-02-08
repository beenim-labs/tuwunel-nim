## sending/dest — service module.
##
## Ported from Rust service/sending/dest.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/sending/dest.rs"
  RustCrate* = "service"

type
  Destination* = enum
    appservice
    string
    push
    owneduserid
    string
    federation
    ownedservername

proc getPrefix*(): seq[u8] =
  ## Ported from `get_prefix`.
  @[]
