## String deserialization helpers.
##
## Ported from Rust core/utils/string/de.rs

import std/json

const
  RustPath* = "core/utils/string/de.rs"
  RustCrate* = "core"

proc deserializeFromStr*[T](j: JsonNode; parser: proc(s: string): T): T =
  ## Deserialize a JSON string value through a parser function.
  if j.kind != JString:
    raise newException(ValueError, "Expected a string value")
  parser(j.getStr())

proc tryDeserializeFromStr*[T](j: JsonNode; parser: proc(s: string): T): T =
  ## Try to deserialize a JSON string, raising on failure.
  if j.kind != JString:
    raise newException(ValueError, "Expected a parsable string")
  try:
    parser(j.getStr())
  except:
    raise newException(ValueError, "Failed to parse string value")
