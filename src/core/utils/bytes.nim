import std/[math, strutils]

const
  RustPath* = "core/utils/bytes.rs"
  RustCrate* = "core"

type ByteSizeParseResult* = tuple[ok: bool, bytes: uint64, message: string]

proc parseUnsignedU64Exact(raw: string): tuple[ok: bool, value: uint64] =
  if raw.len == 0:
    return (false, 0'u64)
  var value = 0'u64
  for ch in raw:
    if ch notin {'0'..'9'}:
      return (false, 0'u64)
    let digit = uint64(ord(ch) - ord('0'))
    if value > (high(uint64) - digit) div 10'u64:
      return (false, 0'u64)
    value = value * 10'u64 + digit
  (true, value)

proc unitMultiplier(unit: string): tuple[ok: bool, multiplier: uint64] =
  case unit.toLowerAscii()
  of "b":
    (true, 1'u64)
  of "k", "kb":
    (true, 1_000'u64)
  of "m", "mb":
    (true, 1_000_000'u64)
  of "g", "gb":
    (true, 1_000_000_000'u64)
  of "t", "tb":
    (true, 1_000_000_000_000'u64)
  of "p", "pb":
    (true, 1_000_000_000_000_000'u64)
  of "e", "eb":
    (true, 1_000_000_000_000_000_000'u64)
  of "ki", "kib":
    (true, 1_024'u64)
  of "mi", "mib":
    (true, 1_048_576'u64)
  of "gi", "gib":
    (true, 1_073_741_824'u64)
  of "ti", "tib":
    (true, 1_099_511_627_776'u64)
  of "pi", "pib":
    (true, 1_125_899_906_842_624'u64)
  of "ei", "eib":
    (true, 1_152_921_504_606_846_976'u64)
  else:
    (false, 0'u64)

proc parseFloatByteCount(numberPart: string; multiplier: uint64): ByteSizeParseResult =
  var value = 0.0
  try:
    value = parseFloat(numberPart)
  except ValueError:
    return (false, 0'u64, "invalid byte size number")

  if value < 0.0 or value.isNaN:
    return (false, 0'u64, "invalid byte size number")

  let scaled = value * float(multiplier)
  if scaled <= 0.0:
    return (true, 0'u64, "")
  if scaled.isNaN:
    return (false, 0'u64, "invalid byte size number")
  if scaled >= float(high(uint64)):
    return (true, high(uint64), "")

  (true, uint64(scaled), "")

proc parseByteSize*(raw: string): ByteSizeParseResult =
  let integer = parseUnsignedU64Exact(raw)
  if integer.ok:
    return (true, integer.value, "")

  var numberEnd = 0
  while numberEnd < raw.len and raw[numberEnd] in {'0'..'9', '.'}:
    inc numberEnd
  if numberEnd == 0:
    return (false, 0'u64, "invalid byte size number")

  let numberPart = raw[0 ..< numberEnd]
  var unitStart = numberEnd
  while unitStart < raw.len and raw[unitStart].isSpaceAscii:
    inc unitStart
  let unitPart = raw[unitStart .. ^1]
  let unit = unitMultiplier(unitPart)
  if not unit.ok:
    return (false, 0'u64, "invalid byte size unit")

  parseFloatByteCount(numberPart, unit.multiplier)

proc deserializeBytesizeU64*(raw: string): ByteSizeParseResult =
  parseByteSize(raw)

proc fromStr*(raw: string): tuple[ok: bool, bytes: int, message: string] =
  let parsed = parseByteSize(raw)
  if not parsed.ok:
    return (false, 0, "Failed to parse byte size: " & parsed.message)
  if parsed.bytes > uint64(high(int)):
    return (false, 0, "Failed to convert u64 to usize")
  (true, int(parsed.bytes), "")

proc deserializeBytesizeUsize*(raw: string): tuple[ok: bool, bytes: int, message: string] =
  fromStr(raw)

proc pretty*(bytes: int): string =
  if bytes < 1024:
    return $bytes & " B"

  const prefixes = ["K", "M", "G", "T", "P", "E"]
  let byteFloat = float(bytes)
  var exponent = int(floor(ln(byteFloat) / ln(1024.0)))
  exponent = min(exponent, prefixes.len)
  let scaled = byteFloat / pow(1024.0, float(exponent))
  formatFloat(scaled, ffDecimal, 1) & " " & prefixes[exponent - 1] & "iB"

proc u64FromBytes*(bytes: openArray[byte]): tuple[ok: bool, value: uint64, message: string] =
  if bytes.len != 8:
    return (false, 0'u64, "expected exactly 8 bytes")

  var value = 0'u64
  for b in bytes:
    value = (value shl 8) or uint64(b)
  (true, value, "")

proc u64FromU8*(bytes: openArray[byte]): uint64 =
  let parsed = u64FromBytes(bytes)
  if not parsed.ok:
    raise newException(ValueError, parsed.message)
  parsed.value

proc increment*(old: openArray[byte]): array[8, byte] =
  result = default(array[8, byte])
  var previous = 0'u64
  if old.len == 8:
    let parsed = u64FromBytes(old)
    if parsed.ok:
      previous = parsed.value

  let next = if previous == high(uint64): 0'u64 else: previous + 1'u64
  for idx in 0 .. 7:
    result[idx] = byte((next shr ((7 - idx) * 8)) and 0xff'u64)
