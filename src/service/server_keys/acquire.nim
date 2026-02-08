## server_keys/acquire — service module.
##
## Ported from Rust service/server_keys/acquire.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/acquire.rs"
  RustCrate* = "service"

proc acquireOrigin*(origin: string; keyIds: seq[OwnedServerSigningKeyId]; timeout: Instant): (string, seq[OwnedServerSigningKeyId]) =
  ## Ported from `acquire_origin`.
  discard

proc acquireNotaryResult*(missing: mut Batch; serverKeys: ServerSigningKeys) =
  ## Ported from `acquire_notary_result`.
  discard

proc keysCount*(batch: Batch): int =
  ## Ported from `keys_count`.
  0
