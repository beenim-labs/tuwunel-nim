## registration_tokens/mod — service module.
##
## Ported from Rust service/registration_tokens/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/registration_tokens/mod.rs"
  RustCrate* = "service"

type
  ValidTokenSource* = enum
    the
    configfile
    a
    database
    databasetokeninfo

type
  Service* = ref object
    discard

type
  ValidToken* = ref object
    token*: string
    source*: ValidTokenSource

proc eq*(self: Service; other: string): bool =
  ## Ported from `eq`.
  false

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc issueToken*(self: Service; expires: TokenExpires): (string =
  ## Ported from `issue_token`.
  discard

proc isEnabled*(self: Service): bool =
  ## Ported from `is_enabled`.
  false

proc getConfigTokens*(self: Service): HashSet<string> =
  ## Ported from `get_config_tokens`.
  discard

proc isTokenValid*(self: Service; token: string) =
  ## Ported from `is_token_valid`.
  discard

proc tryConsume*(self: Service; token: string) =
  ## Ported from `try_consume`.
  discard

proc check*(self: Service; token: string; consume: bool) =
  ## Ported from `check`.
  discard

proc revokeToken*(self: Service; token: string) =
  ## Ported from `revoke_token`.
  discard

proc iterateTokens*(self: Service): impl Stream<Item = ValidToken> + Send + '_ =
  ## Ported from `iterate_tokens`.
  discard
