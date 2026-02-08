## sync/v5 — api module.
##
## Ported from Rust api/client/sync/v5.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/sync/v5.rs"
  RustCrate* = "api"

proc syncEventsV5Route*() =
  ## Ported from `sync_events_v5_route`.
  discard

proc isEmptyResponse*(response: Response): bool =
  ## Ported from `is_empty_response`.
  false
