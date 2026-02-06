## Shared options and filtering for database map reads.

import std/[algorithm, options]
import ../types

type
  MapOrder* = enum
    moForward
    moReverse

  MapReadOptions* = object
    prefix*: Option[seq[byte]]
    startKey*: Option[seq[byte]]
    includeStart*: bool
    limit*: int
    order*: MapOrder

proc compareBytes*(a, b: openArray[byte]): int =
  let m = min(a.len, b.len)
  var i = 0
  while i < m:
    if a[i] < b[i]:
      return -1
    if a[i] > b[i]:
      return 1
    inc i

  if a.len < b.len:
    return -1
  if a.len > b.len:
    return 1
  0

proc hasPrefixBytes*(payload, prefix: openArray[byte]): bool =
  if prefix.len == 0:
    return true
  if payload.len < prefix.len:
    return false

  var i = 0
  while i < prefix.len:
    if payload[i] != prefix[i]:
      return false
    inc i
  true

proc defaultMapReadOptions*(): MapReadOptions =
  MapReadOptions(
    prefix: none(seq[byte]),
    startKey: none(seq[byte]),
    includeStart: true,
    limit: 0,
    order: moForward,
  )

proc withPrefix*(options: MapReadOptions; prefix: openArray[byte]): MapReadOptions =
  result = options
  result.prefix = some(@prefix)

proc withStart*(
    options: MapReadOptions; startKey: openArray[byte]; includeStart = true): MapReadOptions =
  result = options
  result.startKey = some(@startKey)
  result.includeStart = includeStart

proc withLimit*(options: MapReadOptions; limit: int): MapReadOptions =
  result = options
  result.limit = max(0, limit)

proc reversed*(options: MapReadOptions): MapReadOptions =
  result = options
  result.order = moReverse

proc filterEntries*(entries: openArray[DbEntry]; options: MapReadOptions): seq[DbEntry] =
  result = @[]

  var ordered = @entries
  ordered.sort(
    proc(a, b: DbEntry): int =
      compareBytes(a.key, b.key)
  )

  if options.order == moReverse:
    ordered.reverse()

  for entry in ordered:
    if options.prefix.isSome and not hasPrefixBytes(entry.key, options.prefix.get):
      continue

    if options.startKey.isSome:
      let c = compareBytes(entry.key, options.startKey.get)
      if options.order == moForward:
        if c < 0 or (c == 0 and not options.includeStart):
          continue
      else:
        if c > 0 or (c == 0 and not options.includeStart):
          continue

    result.add(entry)
    if options.limit > 0 and result.len >= options.limit:
      break
