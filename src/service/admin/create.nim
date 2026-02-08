## admin/create — service module.
##
## Ported from Rust service/admin/create.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/admin/create.rs"
  RustCrate* = "service"

proc createServerUser*(services: Services) =
  ## Ported from `create_server_user`.
  discard

proc createAdminRoom*(services: Services) =
  ## Ported from `create_admin_room`.
  discard
