## Configuration loader — deserializes config from parsed data.
##
## Ported from Rust config loading logic.

import std/[json, tables, strutils]

const
  RustPath* = "core/config (loader portion)"
  RustCrate* = "core"

proc loadString*(data: JsonNode; key: string; default: string = ""): string =
  ## Load a string value from config, with default.
  if data.hasKey(key) and data[key].kind == JString:
    data[key].getStr()
  else:
    default

proc loadInt*(data: JsonNode; key: string; default: int = 0): int =
  ## Load an integer value from config, with default.
  if data.hasKey(key):
    case data[key].kind
    of JInt: data[key].getInt()
    of JString:
      try: parseInt(data[key].getStr())
      except: default
    else: default
  else:
    default

proc loadBool*(data: JsonNode; key: string; default: bool = false): bool =
  ## Load a boolean value from config, with default.
  if data.hasKey(key):
    case data[key].kind
    of JBool: data[key].getBool()
    of JString: data[key].getStr().toLowerAscii() in ["true", "1", "yes"]
    else: default
  else:
    default

proc loadStringSeq*(data: JsonNode; key: string): seq[string] =
  ## Load a string array from config.
  if data.hasKey(key) and data[key].kind == JArray:
    for item in data[key]:
      if item.kind == JString:
        result.add item.getStr()
