## users/keys — service module.
##
## Ported from Rust service/users/keys.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/keys.rs"
  RustCrate* = "service"

proc addOneTimeKey*(userId: string; deviceId: DeviceId; oneTimeKeyKey: KeyId<OneTimeKeyAlgorithm; oneTimeKeyValue: Raw<OneTimeKey>) =
  ## Ported from `add_one_time_key`.
  discard

proc lastOneTimeKeysUpdate*(userId: string): uint64 =
  ## Ported from `last_one_time_keys_update`.
  0

proc takeOneTimeKey*(userId: string; deviceId: DeviceId; keyAlgorithm: OneTimeKeyAlgorithm): (OwnedKeyId<OneTimeKeyAlgorithm, Raw<OneTimeKey>)> =
  ## Ported from `take_one_time_key`.
  discard

proc countOneTimeKeys*(userId: string; deviceId: DeviceId): BTreeMap<OneTimeKeyAlgorithm, UInt> =
  ## Ported from `count_one_time_keys`.
  discard

proc pruneOneTimeKeys*(userId: string; deviceId: DeviceId) =
  ## Ported from `prune_one_time_keys`.
  discard

proc addDeviceKeys*(userId: string; deviceId: DeviceId; deviceKeys: Raw<DeviceKeys>) =
  ## Ported from `add_device_keys`.
  discard

proc addCrossSigningKeys*(userId: string; masterKey: Option[Raw<CrossSigningKey]>; selfSigningKey: Option[Raw<CrossSigningKey]>; userSigningKey: Option[Raw<CrossSigningKey]>; notify: bool) =
  ## Ported from `add_cross_signing_keys`.
  discard

proc signKey*(targetId: string; keyId: string; signature: (string) =
  ## Ported from `sign_key`.
  discard

proc markDeviceKeyUpdate*(userId: string) =
  ## Ported from `mark_device_key_update`.
  discard

proc getUserSigningKey*(userId: string): Raw<CrossSigningKey> =
  ## Ported from `get_user_signing_key`.
  discard

proc parseMasterKey*(userId: string; masterKey: Raw<CrossSigningKey>): (seq[u8, CrossSigningKey)] =
  ## Ported from `parse_master_key`.
  discard

proc parseUserSigningKey*(userSigningKey: Raw<CrossSigningKey>): string =
  ## Ported from `parse_user_signing_key`.
  ""
