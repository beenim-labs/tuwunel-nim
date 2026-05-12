import std/random

import core/utils/time as time_utils

const
  RustPath* = "core/utils/rand.rs"
  RustCrate* = "core"
  Alphanumeric = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

type UIntRange* = object
  start*: uint64
  stop*: uint64

var randomized = false

proc ensureRandomized() =
  if not randomized:
    randomize()
    randomized = true

proc uintRange*(start, stop: uint64): UIntRange =
  UIntRange(start: start, stop: stop)

proc randomInRange(bounds: UIntRange): uint64 =
  if bounds.stop <= bounds.start:
    return bounds.start
  ensureRandomized()
  let width = bounds.stop - bounds.start
  bounds.start + uint64(rand(int(width - 1'u64)))

proc shuffle*[T](values: var openArray[T]) =
  ensureRandomized()
  for idx in countdown(values.high, 1):
    let swapIdx = rand(idx)
    swap(values[idx], values[swapIdx])

proc string*(length: int): string =
  ensureRandomized()
  result = newString(max(length, 0))
  for idx in 0 ..< result.len:
    result[idx] = Alphanumeric[rand(Alphanumeric.high)]

proc stringArray*(length: int): string =
  string(length)

proc randomBytes(length: int): seq[byte] =
  ensureRandomized()
  result = newSeq[byte](length)
  for idx in 0 ..< length:
    result[idx] = byte(rand(255))

proc base64UrlNoPad(bytes: openArray[byte]): string =
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  result = ""
  var idx = 0
  while idx + 2 < bytes.len:
    let chunk = (uint32(bytes[idx]) shl 16) or (uint32(bytes[idx + 1]) shl 8) or uint32(bytes[idx + 2])
    result.add(alphabet[int((chunk shr 18) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 12) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 6) and 0x3f'u32)])
    result.add(alphabet[int(chunk and 0x3f'u32)])
    inc idx, 3

  let remaining = bytes.len - idx
  if remaining == 1:
    let chunk = uint32(bytes[idx]) shl 16
    result.add(alphabet[int((chunk shr 18) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 12) and 0x3f'u32)])
  elif remaining == 2:
    let chunk = (uint32(bytes[idx]) shl 16) or (uint32(bytes[idx + 1]) shl 8)
    result.add(alphabet[int((chunk shr 18) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 12) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 6) and 0x3f'u32)])

proc eventId*(): string =
  "$" & base64UrlNoPad(randomBytes(32))

proc truncateString*(value: string; bounds: UIntRange): string =
  let charLimit = int(randomInRange(bounds))
  var seen = 0
  for byteIdx, _ in value:
    if seen == charLimit:
      return value[0 ..< byteIdx]
    inc seen
  value

proc truncateStr*(value: string; bounds: UIntRange): string =
  truncateString(value, bounds)

proc secs*(bounds: UIntRange): time_utils.Duration =
  time_utils.durationFromSecs(randomInRange(bounds))

proc timeFromNowSecs*(bounds: UIntRange): time_utils.Timepoint =
  let computed = time_utils.timepointFromNow(secs(bounds))
  if computed.ok:
    computed.timepoint
  else:
    time_utils.Timepoint()
