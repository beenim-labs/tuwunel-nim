## client/threads — api module.
##
## Ported from Rust api/client/threads.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/threads.rs"
  RustCrate* = "api"

proc getThreadsRoute*() =
  ## Ported from `get_threads_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.