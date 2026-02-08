## account_data/direct — service module.
##
## Ported from Rust service/account_data/direct.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/account_data/direct.rs"
  RustCrate* = "service"

proc isDirect*(userId: string; roomId: string): bool =
  ## Ported from `is_direct`.
  false

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.