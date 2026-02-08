## Log capture utilities.
##
## Ported from Rust core/log/capture/util.rs

import ./data
import std/json

const
  RustPath* = "core/log/capture/util.rs"
  RustCrate* = "core"

proc logsToJson*(logs: seq[CapturedLog]): JsonNode =
  ## Convert captured logs to a JSON array.
  result = newJArray()
  for log in logs:
    result.add log.toJson()

proc logsToString*(logs: seq[CapturedLog]; separator: string = "\n"): string =
  ## Format captured logs as a single string.
  var parts: seq[string] = @[]
  for log in logs:
    parts.add log.level & ": " & log.message
  parts.join(separator)

import std/strutils
