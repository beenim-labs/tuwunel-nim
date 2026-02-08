## Byte utilities — u64 parsing, increment, size formatting.
##
## Ported from Rust core/utils/bytes.rs

import std/[strformat, strutils]

const
  RustPath* = "core/utils/bytes.rs"
  RustCrate* = "core"

proc u64FromBytes*(bytes: openArray[byte]): uint64 =
  ## Parse 8 big-endian bytes into a u64.
  if bytes.len < 8:
    raise newException(RangeDefect, "must slice at least 8 bytes")
  (uint64(bytes[0]) shl 56) or
  (uint64(bytes[1]) shl 48) or
  (uint64(bytes[2]) shl 40) or
  (uint64(bytes[3]) shl 32) or
  (uint64(bytes[4]) shl 24) or
  (uint64(bytes[5]) shl 16) or
  (uint64(bytes[6]) shl 8) or
   uint64(bytes[7])

proc u64FromU8*(bytes: openArray[byte]): uint64 =
  ## Parse big-endian bytes into a u64; panic on invalid argument.
  u64FromBytes(bytes)

proc u64ToBytes*(val: uint64): array[8, byte] =
  ## Convert a u64 to 8 big-endian bytes.
  [byte((val shr 56) and 0xFF),
   byte((val shr 48) and 0xFF),
   byte((val shr 40) and 0xFF),
   byte((val shr 32) and 0xFF),
   byte((val shr 24) and 0xFF),
   byte((val shr 16) and 0xFF),
   byte((val shr 8) and 0xFF),
   byte(val and 0xFF)]

proc increment*(old: openArray[byte]): array[8, byte] =
  ## Increment a counter stored as 8 big-endian bytes.
  var current: uint64 = 0
  if old.len >= 8:
    current = u64FromBytes(old)
  u64ToBytes(current + 1)

proc prettyBytes*(bytes: int): string =
  ## Format a byte count into a human-readable IEC string.
  const units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB"]
  var value = float64(bytes)
  var unitIdx = 0
  while value >= 1024.0 and unitIdx < units.high:
    value /= 1024.0
    inc unitIdx
  if unitIdx == 0:
    &"{bytes} {units[0]}"
  else:
    &"{value:.2f} {units[unitIdx]}"

proc bytesFromStr*(s: string): int =
  ## Parse a human-writable byte size string (e.g., "1 KiB", "500 MB").
  ## Simplified parser supporting common suffixes.
  var numStr = ""
  var unitStr = ""
  var inUnit = false
  for ch in s.strip():
    if not inUnit and (ch in '0'..'9' or ch == '.'):
      numStr.add ch
    else:
      inUnit = true
      if ch != ' ':
        unitStr.add ch
  let val = parseFloat(numStr)
  case unitStr.toLowerAscii()
  of "b", "": int(val)
  of "kb", "kib": int(val * 1024.0)
  of "mb", "mib": int(val * 1024.0 * 1024.0)
  of "gb", "gib": int(val * 1024.0 * 1024.0 * 1024.0)
  of "tb", "tib": int(val * 1024.0 * 1024.0 * 1024.0 * 1024.0)
  else:
    raise newException(ValueError, &"unknown byte size unit: '{unitStr}'")

