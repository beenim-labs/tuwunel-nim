## Configuration merge — merge multiple config sources.
##
## Ported from Rust config merge logic.

import std/[json, tables]

const
  RustPath* = "core/config (merge portion)"
  RustCrate* = "core"

proc mergeConfig*(base, overlay: JsonNode): JsonNode =
  ## Deep-merge two JSON config objects. Values in `overlay` take precedence.
  if base.kind != JObject or overlay.kind != JObject:
    return overlay
  result = base.copy()
  for key, value in overlay:
    if result.hasKey(key) and result[key].kind == JObject and value.kind == JObject:
      result[key] = mergeConfig(result[key], value)
    else:
      result[key] = value.copy()

proc mergeConfigs*(configs: openArray[JsonNode]): JsonNode =
  ## Merge multiple config sources in priority order (last wins).
  result = newJObject()
  for config in configs:
    result = mergeConfig(result, config)
