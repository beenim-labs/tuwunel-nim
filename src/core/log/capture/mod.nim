## capture — core module.
##
## Ported from Rust core/log/capture/mod.rs

import std/[options, json, tables]

const
  RustPath* = "core/log/capture/mod.rs"
  RustCrate* = "core"

# import ./data
# import ./layer
# import ./state
# import ./util

type
  Capture* = ref object
    discard

proc start*() =
  ## Ported from `start`.
  discard

proc stop*() =
  ## Ported from `stop`.
  discard
