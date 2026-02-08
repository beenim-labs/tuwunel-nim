## session/password — api module.
##
## Ported from Rust api/client/session/password.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/password.rs"
  RustCrate* = "api"

proc handleLogin*(services: Services; body: Ruma<Request>; info: Password): string =
  ## Ported from `handle_login`.
  ""

proc passwordLogin*(services: Services; userId: string; lowercasedUserId: string; password: string): string =
  ## Ported from `password_login`.
  ""
