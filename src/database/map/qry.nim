## Query helpers for map operations.

import std/options
import ../types
import open
import get
import contains

type
  MapQueryHit* = object
    key*: seq[byte]
    exists*: bool
    value*: Option[seq[byte]]

proc qry*(map: MapHandle; key: openArray[byte]): MapQueryHit =
  let value = map.get(key)
  MapQueryHit(key: @key, exists: value.isSome, value: value)

proc qryRequired*(map: MapHandle; key: openArray[byte]): seq[byte] =
  let hit = map.qry(key)
  if not hit.exists or hit.value.isNone:
    raise newDbError("Query key is absent")
  hit.value.get

proc qryExists*(map: MapHandle; key: openArray[byte]): bool =
  map.contains(key)

proc qryOrDefault*(map: MapHandle; key, fallback: openArray[byte]): seq[byte] =
  let value = map.get(key)
  if value.isSome:
    return value.get
  @fallback

proc qryPrefix*(map: MapHandle; prefix: openArray[byte]): seq[MapQueryHit] =
  result = @[]
  for entry in map.readPrefix(prefix):
    result.add(MapQueryHit(key: entry.key, exists: true, value: some(entry.value)))
