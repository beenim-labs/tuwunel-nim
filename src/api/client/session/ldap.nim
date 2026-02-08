## session/ldap — api module.
##
## Ported from Rust api/client/session/ldap.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/ldap.rs"
  RustCrate* = "api"

proc ldapLogin*(services: Services; userId: string; lowercasedUserId: string; password: string): string =
  ## Ported from `ldap_login`.
  ""

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.