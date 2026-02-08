## registration_tokens/data — service module.
##
## Ported from Rust service/registration_tokens/data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/registration_tokens/data.rs"
  RustCrate* = "service"

type
  DatabaseTokenInfo* = ref object
    uses*: uint64
    expires*: TokenExpires

type
  TokenExpires* = ref object
    maxUses*: Option[uint64]
    maxAge*: Option[SystemTime]

proc isValid*(self: DatabaseTokenInfo): bool =
  ## Ported from `is_valid`.
  false

proc saveToken*(self: DatabaseTokenInfo; token: string; expires: TokenExpires): DatabaseTokenInfo =
  ## Ported from `save_token`.
  discard

proc revokeToken*(self: DatabaseTokenInfo; token: string) =
  ## Ported from `revoke_token`.
  discard

proc checkToken*(self: DatabaseTokenInfo; token: string; consume: bool): bool =
  ## Ported from `check_token`.
  false

proc iterateAndCleanTokens*(self: DatabaseTokenInfo): impl Stream<Item = (string, DatabaseTokenInfo)> + Send + '_ =
  ## Ported from `iterate_and_clean_tokens`.
  discard
