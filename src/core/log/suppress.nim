## Log suppression — temporarily suppress log output.
##
## Ported from Rust core/log/suppress.rs

import std/atomics

const
  RustPath* = "core/log/suppress.rs"
  RustCrate* = "core"

var suppressed: Atomic[bool]

proc suppressLogs*() =
  ## Suppress all log output.
  suppressed.store(true)

proc unsuppressLogs*() =
  ## Restore log output.
  suppressed.store(false)

proc isLogSuppressed*(): bool =
  ## Check if log output is currently suppressed.
  suppressed.load()
