## client/read_marker — api module.
##
## Ported from Rust api/client/read_marker.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/read_marker.rs"
  RustCrate* = "api"

proc setReadMarkerRoute*() =
  ## Ported from `set_read_marker_route`.
  discard

proc createReceiptRoute*() =
  ## Ported from `create_receipt_route`.
  discard
