## router/auth — api module.
##
## Ported from Rust api/router/auth.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/router/auth.rs"
  RustCrate* = "api"

proc auth*(services: Services; request: mut Request; jsonBody: Option[CanonicalJsonValue]; metadata: Metadata): Auth =
  ## Ported from `auth`.
  discard

proc checkAuthStillRequired*(services: Services; metadata: Metadata; token: Token) =
  ## Ported from `check_auth_still_required`.
  discard

proc findToken*(services: Services; token: Option[string]): Token =
  ## Ported from `find_token`.
  discard
