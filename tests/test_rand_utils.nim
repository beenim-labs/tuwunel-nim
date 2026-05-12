import std/[algorithm, strutils, unittest]

import core/utils/rand as rand_utils
import core/utils/time as time_utils

proc isAlphanumeric(value: string): bool =
  for ch in value:
    if not (ch in {'A'..'Z', 'a'..'z', '0'..'9'}):
      return false
  true

proc isUrlSafeBase64EventId(value: string): bool =
  if value.len != 44 or value[0] != '$':
    return false
  for ch in value[1 .. ^1]:
    if not (ch in {'A'..'Z', 'a'..'z', '0'..'9', '-', '_'}):
      return false
  true

suite "rand utility parity":
  test "random strings use Rust alphanumeric shape":
    let generated = rand_utils.string(32)
    check generated.len == 32
    check generated.isAlphanumeric()
    check rand_utils.stringArray(8).len == 8

  test "event ids use Matrix sigil and URL-safe 32-byte base64 without padding":
    let id = rand_utils.eventId()
    check id.isUrlSafeBase64EventId()
    check not id.contains("=")

  test "fixed ranges make duration and truncation deterministic":
    let bounds = rand_utils.uintRange(3, 4)
    check rand_utils.truncateString("abcdef", bounds) == "abc"
    check rand_utils.truncateStr("abcdef", bounds) == "abc"
    check time_utils.asSecs(rand_utils.secs(bounds)) == 3'u64

  test "shuffle preserves elements":
    var values = @[1, 2, 3, 4]
    rand_utils.shuffle(values)
    values.sort()
    check values == @[1, 2, 3, 4]
