## Log formatting utilities.
##
## Ported from Rust core/log/fmt.rs

const
  RustPath* = "core/log/fmt.rs"
  RustCrate* = "core"

proc formatLogLevel*(level: string): string =
  ## Format a log level string with consistent width.
  case level.toLowerAscii()
  of "error": "ERROR"
  of "warn", "warning": " WARN"
  of "info": " INFO"
  of "debug": "DEBUG"
  of "trace": "TRACE"
  else: level

import std/strutils
