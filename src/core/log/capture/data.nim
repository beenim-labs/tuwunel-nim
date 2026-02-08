## Log capture data — structured log storage.
##
## Ported from Rust core/log/capture/data.rs

import std/[times, json]

const
  RustPath* = "core/log/capture/data.rs"
  RustCrate* = "core"

type
  CapturedLog* = object
    ## A single captured log entry.
    level*: string
    message*: string
    target*: string
    timestamp*: DateTime
    fields*: JsonNode

proc newCapturedLog*(level, message, target: string;
    fields: JsonNode = nil): CapturedLog =
  CapturedLog(
    level: level,
    message: message,
    target: target,
    timestamp: now(),
    fields: if fields != nil: fields else: newJObject(),
  )

proc toJson*(log: CapturedLog): JsonNode =
  %*{
    "level": log.level,
    "message": log.message,
    "target": log.target,
    "timestamp": $log.timestamp,
    "fields": log.fields,
  }
