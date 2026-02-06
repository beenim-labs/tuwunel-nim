## Deserialized view helpers built on top of raw database map values.

import std/options
import de
import keyval

type
  DeserializedPair* = object
    keyA*: string
    keyB*: Option[string]

proc deserializePair*(payload: openArray[byte]): DeserializedPair =
  let pair = deserializeTuple2OptionalStringKey(payload)
  DeserializedPair(keyA: pair.a, keyB: pair.b)

proc deserializePairRequired*(payload: openArray[byte]): tuple[a: string, b: string] =
  let pair = deserializeTuple2StringKey(payload)
  (a: pair.a, b: pair.b)

proc deserializeU64Required*(payload: openArray[byte]): uint64 =
  deserializeU64Value(payload)

proc deserializeU64Optional*(payload: Option[seq[byte]]): Option[uint64] =
  if payload.isNone:
    return none(uint64)
  some(deserializeU64Value(payload.get))

proc deserializeStringOptional*(payload: Option[seq[byte]]): Option[string] =
  if payload.isNone:
    return none(string)
  some(deserializeStringValue(payload.get))
