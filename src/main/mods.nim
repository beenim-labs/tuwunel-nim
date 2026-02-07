import std/strutils
import core/config_values

const
  RustPath* = "main/mods.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  RuntimeModuleFlag* = object
    name*: string
    enabled*: bool

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

proc readFlag(values: FlatConfig; key: string; fallback: bool): bool =
  if key in values:
    return valueAsBool(values[key], fallback)
  fallback

proc evaluateRuntimeMods*(values: FlatConfig): seq[RuntimeModuleFlag] =
  @[
    RuntimeModuleFlag(name: "hydra_backports", enabled: readFlag(values, "hydra_backports", false)),
    RuntimeModuleFlag(name: "tokio_console", enabled: readFlag(values, "tokio_console", false)),
    RuntimeModuleFlag(name: "sentry", enabled: readFlag(values, "sentry", false)),
    RuntimeModuleFlag(name: "blurhashing", enabled: readFlag(values, "blurhashing", false)),
    RuntimeModuleFlag(name: "ldap", enabled: readFlag(values, "ldap.enable", false)),
  ]

proc enabledRuntimeMods*(values: FlatConfig): seq[string] =
  result = @[]
  for flag in evaluateRuntimeMods(values):
    if flag.enabled:
      result.add(flag.name)
