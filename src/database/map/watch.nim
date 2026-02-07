## Watch-like helpers for map state changes.

import std/options
import open
import get
import put
import del

type
  MapWatchEvent* = object
    key*: seq[byte]
    existedBefore*: bool
    existsAfter*: bool
    changed*: bool

proc watchPut*(map: MapHandle; key, value: openArray[byte]): MapWatchEvent =
  let before = map.get(key)
  map.put(key, value)
  let after = map.get(key)
  let changed = before.isNone or after.isNone or before.get != after.get
  MapWatchEvent(
    key: @key,
    existedBefore: before.isSome,
    existsAfter: after.isSome,
    changed: changed,
  )

proc watchDel*(map: MapHandle; key: openArray[byte]): MapWatchEvent =
  let before = map.get(key)
  discard map.del(key)
  let after = map.get(key)
  MapWatchEvent(
    key: @key,
    existedBefore: before.isSome,
    existsAfter: after.isSome,
    changed: before.isSome and after.isNone,
  )

proc watchReplace*(
    map: MapHandle; key, oldValue, newValue: openArray[byte]): MapWatchEvent =
  let current = map.get(key)
  if current.isSome and current.get == @oldValue:
    return map.watchPut(key, newValue)

  MapWatchEvent(key: @key, existedBefore: current.isSome, existsAfter: current.isSome, changed: false)

proc watchExists*(map: MapHandle; key: openArray[byte]): MapWatchEvent =
  let value = map.get(key)
  MapWatchEvent(key: @key, existedBefore: value.isSome, existsAfter: value.isSome, changed: false)
