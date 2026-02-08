## client/user_directory — api module.
##
## Ported from Rust api/client/user_directory.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/user_directory.rs"
  RustCrate* = "api"

proc searchUsersRoute*() =
  ## Ported from `search_users_route`.
  discard

proc shouldShowUser*(services: Services; senderUser: string; targetUser: string; targetDisplayName: Option[string]; searchTerm: string): bool =
  ## Ported from `should_show_user`.
  false
