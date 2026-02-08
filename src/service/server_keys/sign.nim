## server_keys/sign — service module.
##
## Ported from Rust service/server_keys/sign.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/sign.rs"
  RustCrate* = "service"

proc genIdHashAndSignEvent*(object: mut CanonicalJsonObject; roomVersionId: RoomVersionId): string =
  ## Ported from `gen_id_hash_and_sign_event`.
  ""

proc genIdHashAndSignEventV1*(object: mut CanonicalJsonObject; roomVersionId: RoomVersionId): string =
  ## Ported from `gen_id_hash_and_sign_event_v1`.
  ""

proc genIdHashAndSignEventV3*(object: mut CanonicalJsonObject; roomVersionId: RoomVersionId): string =
  ## Ported from `gen_id_hash_and_sign_event_v3`.
  ""

proc hashAndSignEvent*(object: mut CanonicalJsonObject; roomVersionId: RoomVersionId) =
  ## Ported from `hash_and_sign_event`.
  discard

proc signJson*(object: mut CanonicalJsonObject) =
  ## Ported from `sign_json`.
  discard
