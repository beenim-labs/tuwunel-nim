## Log color configuration.
##
## Ported from Rust core/log/color.rs

const
  RustPath* = "core/log/color.rs"
  RustCrate* = "core"

type
  LogColor* = enum
    lcAuto   ## Detect based on terminal capability
    lcAlways ## Always use ANSI colors
    lcNever  ## Never use colors

proc shouldColorize*(color: LogColor): bool =
  ## Determine if output should be colorized.
  case color
  of lcAlways: true
  of lcNever: false
  of lcAuto:
    # Check if stdout is a terminal
    when defined(posix):
      import std/terminal
      isatty(stdout)
    else:
      false
