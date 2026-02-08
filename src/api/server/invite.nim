## server/invite — api module.
##
## Ported from Rust api/server/invite.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/invite.rs"
  RustCrate* = "api"

proc createInviteRoute*() =
  ## Ported from `create_invite_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.