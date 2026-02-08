## Default allocator with no special features.
##
## Ported from Rust core/alloc/default.rs

const
  RustPath* = "core/alloc/default.rs"
  RustCrate* = "core"

proc trim*(pad: int = 0): bool =
  ## Always succeeds (no-op).
  true

proc memoryStats*(opts: string = ""): string =
  ## Always returns empty string (no jemalloc).
  ""

proc memoryUsage*(): string =
  ## Always returns empty string (no jemalloc).
  ""
