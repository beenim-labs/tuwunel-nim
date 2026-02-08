## Configuration manager — hot-reloadable configuration.
##
## Ported from Rust core/config/manager.rs

import std/[locks]

const
  RustPath* = "core/config/manager.rs"
  RustCrate* = "core"

type
  ConfigManager*[T] = ref object
    ## Configuration manager with thread-safe reload support.
    ## Allows reading the active config while it can be atomically
    ## swapped for a new version.
    lock: Lock
    active: T

proc newConfigManager*[T](config: T): ConfigManager[T] =
  result = ConfigManager[T](active: config)
  initLock(result.lock)

proc get*[T](m: ConfigManager[T]): T =
  ## Get the active configuration.
  acquire(m.lock)
  result = m.active
  release(m.lock)

proc update*[T](m: ConfigManager[T]; config: T): T =
  ## Update the active configuration, returning the previous one.
  acquire(m.lock)
  result = m.active
  m.active = config
  release(m.lock)
