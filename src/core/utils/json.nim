import std/[algorithm, json, strutils]

const
  RustPath* = "core/utils/json.rs"
  RustCrate* = "core"

type
  CanonicalObjectResult* = tuple[ok: bool, value: JsonNode, message: string]
  ParseStringResult*[T] = tuple[ok: bool, value: T, message: string]

proc toRaw*(input: JsonNode): JsonNode =
  input.copy()

proc canonicalize(value: JsonNode): JsonNode =
  case value.kind
  of JObject:
    result = newJObject()
    var keys: seq[string] = @[]
    for key in value.keys:
      keys.add(key)
    keys.sort()
    for key in keys:
      result[key] = canonicalize(value[key])
  of JArray:
    result = newJArray()
    for item in value:
      result.add(canonicalize(item))
  else:
    result = value.copy()

proc toCanonicalObject*(value: JsonNode): CanonicalObjectResult =
  if value.kind != JObject:
    return (false, newJObject(), "Value must be an object")
  (true, canonicalize(value), "")

proc deserializeIntFromStr*(value: JsonNode): ParseStringResult[int] =
  if value.kind != JString:
    return (false, 0, "expected a parsable string")
  try:
    (true, parseInt(value.getStr()), "")
  except ValueError as err:
    (false, 0, err.msg)

proc deserializeUInt64FromStr*(value: JsonNode): ParseStringResult[uint64] =
  if value.kind != JString:
    return (false, 0'u64, "expected a parsable string")
  try:
    (true, parseUInt(value.getStr()), "")
  except ValueError as err:
    (false, 0'u64, err.msg)

proc deserializeBoolFromStr*(value: JsonNode): ParseStringResult[bool] =
  if value.kind != JString:
    return (false, false, "expected a parsable string")
  case value.getStr().toLowerAscii()
  of "true":
    (true, true, "")
  of "false":
    (true, false, "")
  else:
    (false, false, "invalid bool")
