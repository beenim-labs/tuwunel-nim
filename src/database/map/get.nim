## Get helpers for map operations.

import std/options
import ../db
import ../serialization
import open

proc get*(map: MapHandle; key: openArray[byte]): Option[seq[byte]] =
  map.ensureOpen()
  map.db.get(map.columnFamily, key)

proc getString*(map: MapHandle; key: string): Option[string] =
  let value = map.get(toByteSeq(key))
  if value.isNone:
    return none(string)
  some(fromByteSeq(value.get))

proc getU64*(map: MapHandle; key: openArray[byte]): Option[uint64] =
  let value = map.get(key)
  if value.isNone:
    return none(uint64)
  some(decodeU64BE(value.get))

proc require*(map: MapHandle; key: openArray[byte]): seq[byte] =
  let value = map.get(key)
  if value.isNone:
    raise newException(KeyError, "Key was not found in map")
  value.get

proc getOrDefault*(map: MapHandle; key: openArray[byte]; fallback: seq[byte]): seq[byte] =
  let value = map.get(key)
  if value.isSome:
    return value.get
  fallback

proc hasString*(map: MapHandle; key: string): bool =
  map.getString(key).isSome

proc getMany*(map: MapHandle; keys: openArray[seq[byte]]): seq[Option[seq[byte]]] =
  result = @[]
  for key in keys:
    result.add(map.get(key))
