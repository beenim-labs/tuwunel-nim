const
  RustPath* = "api/server/edu_types.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]
import core/config_values

proc getConfigValue(cfg: FlatConfig; keys: openArray[string]): ConfigValue =
  for key in keys:
    if key in cfg:
      return cfg[key]
  newNullValue()

proc getConfigBool(cfg: FlatConfig; keys: openArray[string]; fallback: bool): bool =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvBool:
    value.b
  of cvString:
    case value.s.toLowerAscii()
    of "1", "true", "yes", "on":
      true
    of "0", "false", "no", "off":
      false
    else:
      fallback
  else:
    fallback

proc eduTypesPayload*(cfg: FlatConfig): JsonNode =
  %*{
    "m.presence": getConfigBool(cfg, ["allow_incoming_presence", "global.allow_incoming_presence"], true),
    "m.receipt": getConfigBool(cfg, ["allow_incoming_read_receipts", "global.allow_incoming_read_receipts"], true),
    "m.typing": getConfigBool(cfg, ["allow_incoming_typing", "global.allow_incoming_typing"], true),
  }
