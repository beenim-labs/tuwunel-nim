## session/appservice — api module.
##
## Ported from Rust api/client/session/appservice.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/appservice.rs"
  RustCrate* = "api"

proc handleLogin*(services: Services; body: Ruma<Request>; info: ApplicationService): string =
  ## Ported from `handle_login`.
  ""

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.