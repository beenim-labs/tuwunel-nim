## Serializer helpers for parity-focused database key/value encoding.

import std/options
import serialization
import types

const
  RecordSeparator* = Sep

proc fail(msg: string): ref DbError {.inline.} =
  newDbError(msg)

proc serializeBytes*(value: openArray[byte]): seq[byte] =
  @value

proc serializeU64*(value: uint64): seq[byte] =
  encodeU64BE(value)

proc serializeI64*(value: int64): seq[byte] =
  encodeI64BE(value)

proc serializeU32*(value: uint32): seq[byte] =
  encodeU32BE(value)

proc serializeString*(value: string; allowTopLevel = false): seq[byte] =
  ## Rust serializer rejects top-level strings in debug builds.
  if not allowTopLevel:
    raise fail("serializing string at the top-level is not permitted")
  toByteSeq(value)

proc serializeTuple*(records: openArray[seq[byte]]): seq[byte] =
  serializeRecords(records)

proc serializeTuple2*(a, b: seq[byte]): seq[byte] =
  serializeTuple([a, b])

proc serializeTuple3*(a, b, c: seq[byte]): seq[byte] =
  serializeTuple([a, b, c])

proc serializeTupleOptionFirst*(a: Option[seq[byte]]; b: seq[byte]): seq[byte] =
  if a.isSome:
    serializeTuple2(a.get, b)
  else:
    serializeTuple2(@[], b)

proc serializeU64Array*(values: openArray[uint64]): seq[byte] =
  result = @[]
  for v in values:
    result.add(serializeU64(v))

