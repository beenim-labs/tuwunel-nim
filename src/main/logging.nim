import std/strutils
import core/[config_values, logging]

const
  RustPath* = "main/logging.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  LoggingPlan* = object
    level*: string
    enabled*: bool
    toStderr*: bool
    compact*: bool

proc valueAsBool(value: ConfigValue; fallback: bool): bool =
  case value.kind
  of cvBool:
    value.b
  of cvInt:
    value.i != 0
  of cvString:
    value.s.toLowerAscii() in ["1", "true", "yes", "on"]
  else:
    fallback

proc valueAsString(value: ConfigValue; fallback: string): string =
  case value.kind
  of cvString:
    value.s
  else:
    fallback

proc readBool(values: FlatConfig; key: string; fallback: bool): bool =
  if key in values:
    return valueAsBool(values[key], fallback)
  fallback

proc readString(values: FlatConfig; key, fallback: string): string =
  if key in values:
    return valueAsString(values[key], fallback)
  fallback

proc buildLoggingPlan*(values: FlatConfig): LoggingPlan =
  LoggingPlan(
    level: readString(values, "log", "info"),
    enabled: readBool(values, "log_enable", true),
    toStderr: readBool(values, "log_to_stderr", true),
    compact: readBool(values, "log_compact", false),
  )

proc applyLoggingPlan*(plan: LoggingPlan) =
  if not plan.enabled:
    return
  info("logging_plan level=" & plan.level & " compact=" & $plan.compact)
