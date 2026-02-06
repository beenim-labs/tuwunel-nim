## Batch retrieval helpers for map operations.

import std/options
import open
import get
import contains

proc getBatch*(map: MapHandle; keys: openArray[seq[byte]]): seq[Option[seq[byte]]] =
  result = @[]
  for key in keys:
    result.add(map.get(key))

proc getBatchHits*(map: MapHandle; keys: openArray[seq[byte]]): seq[seq[byte]] =
  result = @[]
  for value in map.getBatch(keys):
    if value.isSome:
      result.add(value.get)

proc getBatchMisses*(map: MapHandle; keys: openArray[seq[byte]]): seq[seq[byte]] =
  result = @[]
  for key in keys:
    if not map.contains(key):
      result.add(key)

proc getBatchPairs*(
    map: MapHandle; keys: openArray[seq[byte]]): seq[tuple[key: seq[byte], value: seq[byte]]] =
  result = @[]
  for key in keys:
    let value = map.get(key)
    if value.isSome:
      result.add((key: key, value: value.get))

proc getBatchCount*(map: MapHandle; keys: openArray[seq[byte]]): tuple[hits: int, misses: int] =
  result = (hits: 0, misses: 0)
  for key in keys:
    if map.contains(key):
      inc result.hits
    else:
      inc result.misses
