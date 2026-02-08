## server_keys/request — service module.
##
## Ported from Rust service/server_keys/request.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/request.rs"
  RustCrate* = "service"

proc notaryRequest*(notary: string; target: string): impl Iterator<Item = ServerSigningKeys + Clone + Debug + Send + use<>> =
  ## Ported from `notary_request`.
  discard

proc serverRequest*(target: string): ServerSigningKeys =
  ## Ported from `server_request`.
  discard
