## Unsigned event data handling.
##
## Ported from Rust core/matrix/event/unsigned.rs — provides utilities
## for accessing the `unsigned` object on events, including property
## checking and typed extraction.

import std/[json, options]
import ../event

const
  RustPath* = "core/matrix/event/unsigned.rs"
  RustCrate* = "core"

proc containsUnsignedProp*(event: Event; property: string;
                           isType: proc(n: JsonNode): bool): bool =
  ## Check if the unsigned data contains a property matching a type predicate.
  let unsigned = event.getUnsignedAsValue()
  if unsigned.kind != JObject or not unsigned.hasKey(property):
    return false
  isType(unsigned[property])

proc getUnsignedProp*(event: Event; property: string): Option[JsonNode] =
  ## Get a property from the unsigned data.
  let unsigned = event.getUnsignedAsValue()
  if unsigned.kind == JObject and unsigned.hasKey(property):
    some(unsigned[property])
  else:
    none(JsonNode)

proc getUnsignedString*(event: Event; property: string): Option[string] =
  ## Get a string property from unsigned data.
  let val = event.getUnsignedProp(property)
  if val.isSome and val.get().kind == JString:
    some(val.get().getStr())
  else:
    none(string)

proc getUnsignedInt*(event: Event; property: string): Option[int64] =
  ## Get an integer property from unsigned data.
  let val = event.getUnsignedProp(property)
  if val.isSome and val.get().kind == JInt:
    some(val.get().getBiggestInt())
  else:
    none(int64)

proc getAge*(event: Event): Option[int64] =
  ## Get the age (in milliseconds) from unsigned data.
  event.getUnsignedInt("age")

proc getTransactionId*(event: Event): Option[string] =
  ## Get the transaction ID from unsigned data.
  event.getUnsignedString("transaction_id")

proc setUnsignedProperty*(event: Event; property: string; value: JsonNode) =
  ## Set a property in the unsigned data (mutating).
  if event.unsigned.isNone:
    event.unsigned = some(newJObject())
  event.unsigned.get()[property] = value
