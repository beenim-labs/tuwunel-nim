## Compute utilities — CPU parallelism.
##
## Ported from Rust core/utils/sys/compute.rs

import std/cpuinfo

const
  RustPath* = "core/utils/sys/compute.rs"
  RustCrate* = "core"

proc availableParallelism*(): int =
  ## Return the number of available CPU cores/threads.
  max(1, countProcessors())

proc hardwareThreads*(): int =
  ## Alias for availableParallelism.
  availableParallelism()
