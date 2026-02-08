## spaces/pagination_token — service module.
##
## Ported from Rust service/rooms/spaces/pagination_token.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/spaces/pagination_token.rs"
  RustCrate* = "service"

type
  PaginationToken* = ref object
    shortRoomIds*: seq[Shortstring]
    limit*: UInt
    maxDepth*: UInt
    suggestedOnly*: bool

proc fromStr*(value: string) =
  ## Ported from `from_str`.
  discard
