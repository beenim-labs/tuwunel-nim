## session/jwt — api module.
##
## Ported from Rust api/client/session/jwt.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/session/jwt.rs"
  RustCrate* = "api"

proc handleLogin*(services: Services; Body: Ruma<Request>; info: Token): string =
  ## Ported from `handle_login`.
  ""

proc validateUser*(services: Services; token: string): string =
  ## Ported from `validate_user`.
  ""

proc validate*(config: JwtConfig; token: string): Claim =
  ## Ported from `validate`.
  discard

proc initVerifier*(config: JwtConfig): DecodingKey =
  ## Ported from `init_verifier`.
  discard

proc initValidator*(config: JwtConfig): Validation =
  ## Ported from `init_validator`.
  discard
