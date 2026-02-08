## JSON utilities — canonical object conversion, deserialization helpers.
##
## Ported from Rust core/utils/json.rs — simplified for Nim's json module.

import std/[json, algorithm]

const
  RustPath* = "core/utils/json.rs"
  RustCrate* = "core"

proc toCanonicalObject*(j: JsonNode): JsonNode =
  ## Convert a JSON value to a canonical JSON object.
  ## Raises ValueError if input is not an object.
  if j.kind != JObject:
    raise newException(ValueError, "Value must be an object")
  # Return a copy with sorted keys (canonical form)
  result = newJObject()
  var keys: seq[string] = @[]
  for k in j.keys:
    keys.add k
  keys.sort()
  for k in keys:
    result[k] = j[k]

proc canonicalJsonBytes*(j: JsonNode): string =
  ## Serialize a JSON object to canonical JSON bytes (sorted keys, no
  ## extra whitespace).
  toCanonicalObject(j).pretty(0)

proc getStr*(j: JsonNode; key: string; default: string = ""): string =
  ## Get a string value from a JSON object, returning default if missing
  ## or not a string.
  if j.kind == JObject and j.hasKey(key):
    let v = j[key]
    if v.kind == JString:
      return v.getStr()
  default

proc getInt*(j: JsonNode; key: string; default: int = 0): int =
  ## Get an integer value from a JSON object.
  if j.kind == JObject and j.hasKey(key):
    let v = j[key]
    if v.kind == JInt:
      return v.getInt()
  default

proc getBool*(j: JsonNode; key: string; default: bool = false): bool =
  ## Get a boolean value from a JSON object.
  if j.kind == JObject and j.hasKey(key):
    let v = j[key]
    if v.kind == JBool:
      return v.getBool()
  default

