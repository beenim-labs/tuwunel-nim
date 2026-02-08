## session/token — api module.
##
## Ported from Rust api/client/session/token.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/token.rs"
  RustCrate* = "api"

proc handleLogin*(services: Services; Body: Ruma<Request>; info: Token): string =
  ## Ported from `handle_login`.
  ""

proc loginTokenRoute*() =
  ## Ported from `login_token_route`.
  discard
