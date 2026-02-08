## Console logging — log output to stdout/stderr.
##
## Ported from Rust core/log/console.rs

import std/[logging, strformat, times]

const
  RustPath* = "core/log/console.rs"
  RustCrate* = "core"

type
  ConsoleLogger* = ref object of Logger
    ## Console logger with configurable format.
    useColors*: bool
    showTimestamp*: bool

proc newConsoleLogger*(level: Level = lvlInfo;
    useColors: bool = true;
    showTimestamp: bool = true): ConsoleLogger =
  result = ConsoleLogger(
    levelThreshold: level,
    useColors: useColors,
    showTimestamp: showTimestamp,
  )

method log*(logger: ConsoleLogger; level: Level; args: varargs[string, `$`]) =
  if level < logger.levelThreshold:
    return
  let prefix = if logger.showTimestamp:
    &"[{now().format(\"yyyy-MM-dd HH:mm:ss\")}] "
  else:
    ""
  let levelStr = case level
    of lvlAll: "ALL"
    of lvlDebug: "DEBUG"
    of lvlInfo: "INFO"
    of lvlNotice: "NOTICE"
    of lvlWarn: "WARN"
    of lvlError: "ERROR"
    of lvlFatal: "FATAL"
    of lvlNone: "NONE"
  var msg = ""
  for arg in args:
    msg.add arg
  stderr.writeLine(&"{prefix}{levelStr}: {msg}")
