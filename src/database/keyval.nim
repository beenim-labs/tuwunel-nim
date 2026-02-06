## Key/value encoding helpers backed by ser/de primitives.

import std/options
import de
import ser
import serialization

proc serializeKey*(parts: openArray[seq[byte]]): seq[byte] =
  serializeTuple(parts)

proc serializeStringKey*(parts: openArray[string]): seq[byte] =
  var records: seq[seq[byte]] = @[]
  for p in parts:
    records.add(toByteSeq(p))
  serializeKey(records)

proc serializeValue*(value: openArray[byte]): seq[byte] =
  serializeBytes(value)

proc serializeStringValue*(value: string): seq[byte] =
  serializeString(value, allowTopLevel = true)

proc serializeU64Value*(value: uint64): seq[byte] =
  serializeU64(value)

proc deserializeStringValue*(value: openArray[byte]): string =
  fromByteSeq(value)

proc deserializeU64Value*(value: openArray[byte]): uint64 =
  deserializeU64(value)

proc deserializeTuple2StringKey*(payload: openArray[byte]): tuple[a: string, b: string] =
  let decoded = deserializeTuple2Bytes(payload)
  (fromByteSeq(decoded.a), fromByteSeq(decoded.b))

proc deserializeTuple2OptionalStringKey*(
    payload: openArray[byte]): tuple[a: string, b: Option[string]] =
  let decoded = deserializeTuple2OptionalSecond(payload)
  if decoded.b.isSome:
    return (fromByteSeq(decoded.a), some(fromByteSeq(decoded.b.get)))
  (fromByteSeq(decoded.a), none(string))

