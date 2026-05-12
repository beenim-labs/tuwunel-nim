import std/unittest

import core/utils/bytes as bytes_utils

proc bytes8(values: openArray[int]): array[8, byte] =
  result = default(array[8, byte])
  doAssert values.len == 8
  for idx, value in values:
    result[idx] = byte(value)

suite "core bytes utility parity":
  test "parse byte sizes with integer, SI, and IEC units":
    let plain = bytes_utils.parseByteSize("1024")
    check plain.ok
    check plain.bytes == 1024'u64

    let kib = bytes_utils.parseByteSize("1 KiB")
    check kib.ok
    check kib.bytes == 1024'u64

    let fractional = bytes_utils.parseByteSize("1.5 KiB")
    check fractional.ok
    check fractional.bytes == 1536'u64

    let si = bytes_utils.parseByteSize("2 MB")
    check si.ok
    check si.bytes == 2_000_000'u64

  test "parse byte size failures match strict Rust suffix handling":
    check not bytes_utils.parseByteSize("").ok
    check not bytes_utils.parseByteSize("1 bytes").ok
    check not bytes_utils.parseByteSize("1 KiB ").ok
    check not bytes_utils.parseByteSize("-1 KiB").ok

  test "fromStr and serde helper equivalents expose usize and u64 results":
    let usizeParsed = bytes_utils.fromStr("24 MiB")
    check usizeParsed.ok
    check usizeParsed.bytes == 25_165_824

    let u64Parsed = bytes_utils.deserializeBytesizeU64("32 MiB")
    check u64Parsed.ok
    check u64Parsed.bytes == 33_554_432'u64

  test "pretty renders IEC units":
    check bytes_utils.pretty(0) == "0 B"
    check bytes_utils.pretty(1023) == "1023 B"
    check bytes_utils.pretty(1024) == "1.0 KiB"
    check bytes_utils.pretty(1536) == "1.5 KiB"

  test "big endian u64 parsing and increment wrap like Rust":
    let five = bytes8([0, 0, 0, 0, 0, 0, 0, 5])
    let parsed = bytes_utils.u64FromBytes(five)
    check parsed.ok
    check parsed.value == 5'u64
    check bytes_utils.u64FromU8(five) == 5'u64

    check not bytes_utils.u64FromBytes([byte(1), byte(2)]).ok
    expect ValueError:
      discard bytes_utils.u64FromU8([byte(1), byte(2)])

    check bytes_utils.increment(five) == bytes8([0, 0, 0, 0, 0, 0, 0, 6])
    check bytes_utils.increment(bytes8([255, 255, 255, 255, 255, 255, 255, 255])) ==
      bytes8([0, 0, 0, 0, 0, 0, 0, 0])
    check bytes_utils.increment([]) == bytes8([0, 0, 0, 0, 0, 0, 0, 1])
