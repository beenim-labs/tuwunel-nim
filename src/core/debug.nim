## Debug utilities — panic handlers, debug logging, type introspection.
##
## Ported from Rust core/debug.rs

import std/[os, logging]

const
  RustPath* = "core/debug.rs"
  RustCrate* = "core"

proc isDebugBuild*(): bool =
  ## Check if this is a debug build.
  when defined(debug):
    true
  else:
    false

proc debugLogging*(): bool =
  ## Returns true if debug logging is enabled.
  when defined(debug):
    true
  elif defined(tuwunelDebugLogging):
    true
  else:
    false

proc isDebuggerAttached*(): bool =
  ## Heuristic check if a debugger is attached.
  let parent = getEnv("_", "")
  parent.endsWith("gdb") or parent.endsWith("lldb")

proc typeName*[T](v: T): string =
  ## Return the type name of a value (runtime).
  $typeof(v)

proc panicStr*(msg: string): string =
  ## Extract a panic message string.
  msg

template debugEvent*(level: Level; msg: string) =
  ## Log event at given level in debug mode, DEBUG level in release.
  when defined(debug):
    log(level, msg)
  else:
    debug(msg)

template debugError*(msg: string) =
  ## Log at ERROR in debug, DEBUG in release.
  debugEvent(lvlError, msg)

template debugWarn*(msg: string) =
  ## Log at WARN in debug, DEBUG in release.
  debugEvent(lvlWarn, msg)

template debugInfo*(msg: string) =
  ## Log at INFO in debug, DEBUG in release.
  debugEvent(lvlInfo, msg)
