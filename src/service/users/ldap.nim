## users/ldap — service module.
##
## Ported from Rust service/users/ldap.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/ldap.rs"
  RustCrate* = "service"

proc searchLdap*(userId: string): seq[(string] =
  ## Ported from `search_ldap`.
  @[]

proc authLdap*(userDn: string; password: string) =
  ## Ported from `auth_ldap`.
  discard
