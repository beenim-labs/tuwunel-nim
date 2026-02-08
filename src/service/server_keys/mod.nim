## server_keys/mod — service module.
##
## Ported from Rust service/server_keys/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc keypair*(self: Service): Ed25519KeyPair =
  ## Ported from `keypair`.
  discard

proc activeKeyId*(self: Service): ServerSigningKeyId =
  ## Ported from `active_key_id`.
  discard

proc activeVerifyKey*(self: Service): (ServerSigningKeyId, VerifyKey) =
  ## Ported from `active_verify_key`.
  discard

proc addSigningKeys*(self: Service; newKeys: ServerSigningKeys) =
  ## Ported from `add_signing_keys`.
  discard

proc requiredKeysExist*(self: Service; object: CanonicalJsonObject; rules: RoomVersionRules): bool =
  ## Ported from `required_keys_exist`.
  false

proc verifyKeyExists*(self: Service; origin: string; keyId: ServerSigningKeyId): bool =
  ## Ported from `verify_key_exists`.
  false

proc verifyKeysFor*(self: Service; origin: string): VerifyKeys =
  ## Ported from `verify_keys_for`.
  discard

proc signingKeysFor*(self: Service; origin: string): ServerSigningKeys =
  ## Ported from `signing_keys_for`.
  discard

proc minimumValidTs*(self: Service): MilliSecondsSinceUnixEpoch =
  ## Ported from `minimum_valid_ts`.
  discard

proc mergeOldKeys*(keys: ServerSigningKeys): ServerSigningKeys =
  ## Ported from `merge_old_keys`.
  discard

proc extractKey*(keys: ServerSigningKeys; keyId: ServerSigningKeyId): Option[VerifyKey] =
  ## Ported from `extract_key`.
  none(VerifyKey)

proc keyExists*(keys: ServerSigningKeys; keyId: ServerSigningKeyId): bool =
  ## Ported from `key_exists`.
  false
