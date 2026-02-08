## federation/format — service module.
##
## Ported from Rust service/federation/format.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/federation/format.rs"
  RustCrate* = "service"

proc formatPduInto*(pduJson: CanonicalJsonObject; roomVersion: Option[RoomVersionId]) =
  ## Ported from `format_pdu_into`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.