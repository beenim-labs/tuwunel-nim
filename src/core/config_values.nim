## Configuration values — typed accessors for config keys.
##
## Ported from Rust config value access patterns.

import std/[json, strutils, options]

const
  RustPath* = "core/config (values portion)"
  RustCrate* = "core"

type
  ConfigValues* = ref object
    ## Typed configuration value store.
    data*: JsonNode

proc newConfigValues*(data: JsonNode): ConfigValues =
  ConfigValues(data: data)

proc getString*(cv: ConfigValues; key: string; default: string = ""): string =
  if cv.data.hasKey(key) and cv.data[key].kind == JString:
    cv.data[key].getStr()
  else:
    default

proc getInt*(cv: ConfigValues; key: string; default: int = 0): int =
  if cv.data.hasKey(key) and cv.data[key].kind == JInt:
    cv.data[key].getInt()
  else:
    default

proc getBool*(cv: ConfigValues; key: string; default: bool = false): bool =
  if cv.data.hasKey(key) and cv.data[key].kind == JBool:
    cv.data[key].getBool()
  else:
    default

proc getOptString*(cv: ConfigValues; key: string): Option[string] =
  if cv.data.hasKey(key) and cv.data[key].kind == JString:
    some(cv.data[key].getStr())
  else:
    none(string)

proc hasKey*(cv: ConfigValues; key: string): bool =
  cv.data.hasKey(key)
