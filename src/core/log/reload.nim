## Log level reload support.
##
## Ported from Rust core/log/reload.rs

import std/[logging, atomics]

const
  RustPath* = "core/log/reload.rs"
  RustCrate* = "core"

var currentLevel: Atomic[int]

proc initReloadableLevel*(level: Level) =
  ## Initialize the reloadable log level.
  currentLevel.store(ord(level))

proc reloadLevel*(level: Level) =
  ## Reload the log level at runtime.
  currentLevel.store(ord(level))

proc getReloadableLevel*(): Level =
  ## Get the current reloadable log level.
  Level(currentLevel.load())
