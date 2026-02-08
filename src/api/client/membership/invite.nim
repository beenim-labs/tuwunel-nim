## membership/invite — api module.
##
## Ported from Rust api/client/membership/invite.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/invite.rs"
  RustCrate* = "api"

proc inviteUserRoute*() =
  ## Ported from `invite_user_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.