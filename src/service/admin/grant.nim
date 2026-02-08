## admin/grant — service module.
##
## Ported from Rust service/admin/grant.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/admin/grant.rs"
  RustCrate* = "service"

proc makeUserAdmin*(userId: string) =
  ## Ported from `make_user_admin`.
  discard

proc revokeAdmin*(userId: string) =
  ## Ported from `revoke_admin`.
  discard
