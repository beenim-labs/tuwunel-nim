## Batch query helpers for map operations.

import std/options
import qry
import get_batch
import open

proc qryBatch*(map: MapHandle; keys: openArray[seq[byte]]): seq[MapQueryHit] =
  result = @[]
  for key in keys:
    result.add(map.qry(key))

proc qryBatchValues*(map: MapHandle; keys: openArray[seq[byte]]): seq[Option[seq[byte]]] =
  map.getBatch(keys)

proc qryBatchExisting*(map: MapHandle; keys: openArray[seq[byte]]): seq[MapQueryHit] =
  result = @[]
  for hit in map.qryBatch(keys):
    if hit.exists:
      result.add(hit)

proc qryBatchMissing*(map: MapHandle; keys: openArray[seq[byte]]): seq[seq[byte]] =
  result = @[]
  for hit in map.qryBatch(keys):
    if not hit.exists:
      result.add(hit.key)

proc qryBatchStats*(map: MapHandle; keys: openArray[seq[byte]]): tuple[hits: int, misses: int] =
  result = (hits: 0, misses: 0)
  for hit in map.qryBatch(keys):
    if hit.exists:
      inc result.hits
    else:
      inc result.misses
