## client/keys — api module.
##
## Ported from Rust api/client/keys.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/keys.rs"
  RustCrate* = "api"

proc uploadKeysRoute*() =
  ## Ported from `upload_keys_route`.
  discard

proc getKeysRoute*() =
  ## Ported from `get_keys_route`.
  discard

proc claimKeysRoute*() =
  ## Ported from `claim_keys_route`.
  discard

proc uploadSigningKeysRoute*() =
  ## Ported from `upload_signing_keys_route`.
  discard

proc checkForNewKeys*(services: crate::State; userId: string; selfSigningKey: Option[Raw<CrossSigningKey]>; userSigningKey: Option[Raw<CrossSigningKey]>; masterSigningKey: Option[Raw<CrossSigningKey]>): Option[upload_signing_keys::v3::Response] =
  ## Ported from `check_for_new_keys`.
  none(upload_signing_keys::v3::Response)

proc uploadSignaturesRoute*() =
  ## Ported from `upload_signatures_route`.
  discard

proc getKeyChangesRoute*() =
  ## Ported from `get_key_changes_route`.
  discard

proc addUnsignedDeviceDisplayName*(keys: mut Raw<ruma::encryption::DeviceKeys>; metadata: ruma::api::client::device::Device; includeDisplayNames: bool) =
  ## Ported from `add_unsigned_device_display_name`.
  discard

proc claimKeysHelper*(services: Services; oneTimeKeysInput: BTreeMap<string): claim_keys::v3::Response =
  ## Ported from `claim_keys_helper`.
  discard
