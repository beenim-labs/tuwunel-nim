## Deserializer helpers for parity-focused database key/value decoding.

import std/options
import serialization
import types

proc fail(msg: string): ref DbError {.inline.} =
  newDbError(msg)

proc splitTuple*(payload: openArray[byte]): seq[seq[byte]] =
  splitRecords(payload)

proc deserializeU64*(payload: openArray[byte]): uint64 =
  decodeU64BE(payload)

proc deserializeI64*(payload: openArray[byte]): int64 =
  decodeI64BE(payload)

proc deserializeU32*(payload: openArray[byte]): uint32 =
  decodeU32BE(payload)

proc deserializeTuple2Bytes*(payload: openArray[byte]): tuple[a: seq[byte], b: seq[byte]] =
  let records = splitTuple(payload)
  if records.len != 2:
    raise fail("failed to deserialize tuple2: expected exactly 2 records")
  (records[0], records[1])

proc deserializeTuple2DefaultSecond*(
    payload: openArray[byte]): tuple[a: seq[byte], b: seq[byte]] =
  let records = splitTuple(payload)
  case records.len
  of 1:
    (records[0], @[])
  of 2:
    (records[0], records[1])
  else:
    raise fail("failed to deserialize tuple2: expected 1 or 2 records")

proc deserializeTuple2OptionalSecond*(
    payload: openArray[byte]): tuple[a: seq[byte], b: Option[seq[byte]]] =
  let records = splitTuple(payload)
  case records.len
  of 1:
    (records[0], none(seq[byte]))
  of 2:
    if records[1].len == 0:
      (records[0], none(seq[byte]))
    else:
      (records[0], some(records[1]))
  else:
    raise fail("failed to deserialize tuple2 optional: expected 1 or 2 records")

proc deserializeTupleOptionFirst*(
    payload: openArray[byte]): tuple[a: Option[seq[byte]], b: seq[byte]] =
  let records = splitTuple(payload)
  if records.len != 2:
    raise fail("failed to deserialize tuple option-first: expected exactly 2 records")

  let first = if records[0].len == 0: none(seq[byte]) else: some(records[0])
  (first, records[1])

proc deserializeU64Array*(payload: openArray[byte]): seq[uint64] =
  if payload.len mod 8 != 0:
    raise fail("failed to deserialize u64 array: length is not a multiple of 8")

  result = @[]
  var i = 0
  while i < payload.len:
    result.add(deserializeU64(payload[i ..< i + 8]))
    i += 8

