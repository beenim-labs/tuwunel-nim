## Logging subsystem — initialization and management.
##
## Ported from Rust core/log/mod.rs

import std/logging

const
  RustPath* = "core/log/mod.rs"
  RustCrate* = "core"

type
  Logging* = ref object
    ## Logging subsystem state.
    initialized*: bool
    level*: Level

proc newLogging*(level: Level = lvlInfo): Logging =
  Logging(initialized: false, level: level)

proc init*(lg: Logging) =
  ## Initialize the logging subsystem.
  if not lg.initialized:
    addHandler(newConsoleLogger(lg.level))
    lg.initialized = true

proc setLevel*(lg: Logging; level: Level) =
  ## Change the active log level.
  lg.level = level
