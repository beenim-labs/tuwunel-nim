## Logging convenience module — re-exports log subsystem.
##
## Ported from Rust core/logging (the top-level convenience import).

import ./log/mod as logMod
export logMod

const
  RustPath* = "core/logging"
  RustCrate* = "core"
