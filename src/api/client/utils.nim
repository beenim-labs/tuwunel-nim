## client/utils — api module.
##
## Ported from Rust api/client/utils.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/utils.rs"
  RustCrate* = "api"

proc inviteCheck*(services: Services; senderUser: string; roomId: string) =
  ## Ported from `invite_check`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.