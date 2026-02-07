import std/strutils
import core/config_values

const
  RustPath* = "main/restart.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RestartDecision* = object
    requested*: bool
    reason*: string
    delayMs*: int

proc requestRestart*(reason: string; delayMs = 0): RestartDecision =
  RestartDecision(
    requested: true,
    reason: reason,
    delayMs: max(0, delayMs),
  )

proc valueAsString(value: ConfigValue): string =
  case value.kind
  of cvString:
    value.s
  of cvArray:
    if value.items.len > 0:
      return valueAsString(value.items[^1])
    ""
  else:
    ""

proc evaluateRestartDecision*(values: FlatConfig): RestartDecision =
  if "admin_execute" notin values:
    return RestartDecision(requested: false, reason: "", delayMs: 0)

  let commandText = valueAsString(values["admin_execute"]).toLowerAscii()
  if commandText.contains("restart"):
    return requestRestart("admin_execute requested restart", delayMs = 0)

  RestartDecision(requested: false, reason: "", delayMs: 0)
