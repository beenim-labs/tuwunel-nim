## server_keys/get — service module.
##
## Ported from Rust service/server_keys/get.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/get.rs"
  RustCrate* = "service"

proc getEventKeys*(object: CanonicalJsonObject; version: RoomVersionRules): PubKeyMap =
  ## Ported from `get_event_keys`.
  discard

proc getVerifyKey*(origin: string; keyId: ServerSigningKeyId): VerifyKey =
  ## Ported from `get_verify_key`.
  discard

proc getVerifyKeyFromNotaries*(origin: string; keyId: ServerSigningKeyId): VerifyKey =
  ## Ported from `get_verify_key_from_notaries`.
  discard

proc getVerifyKeyFromOrigin*(origin: string; keyId: ServerSigningKeyId): VerifyKey =
  ## Ported from `get_verify_key_from_origin`.
  discard
