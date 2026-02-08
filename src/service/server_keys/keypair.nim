## server_keys/keypair — service module.
##
## Ported from Rust service/server_keys/keypair.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/server_keys/keypair.rs"
  RustCrate* = "service"

proc init*(db: Database): (RootRef =
  ## Ported from `init`.
  discard

proc load*(db: Database) =
  ## Ported from `load`.
  discard

proc create*(db: Database): (string)> =
  ## Ported from `create`.
  discard

proc remove*(db: Database) =
  ## Ported from `remove`.
  discard
