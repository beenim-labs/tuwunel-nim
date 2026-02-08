## Debug utilities — truncated formatting for slices and strings.
##
## Ported from Rust core/utils/debug.rs

import std/strutils

const
  RustPath* = "core/utils/debug.rs"
  RustCrate* = "core"

proc sliceTruncated*[T](s: openArray[T]; maxLen: int): string =
  ## Debug-format a slice, showing only up to maxLen elements.
  ## Further elements replaced by "...".
  if s.len <= maxLen:
    return $(@s)
  var parts: seq[string] = @[]
  for i in 0 ..< maxLen:
    parts.add $s[i]
  parts.add "..."
  "[" & parts.join(", ") & "]"

proc strTruncated*(s: string; maxLen: int): string =
  ## Debug-format a string, truncating to maxLen characters.
  if s.len <= maxLen:
    return "\"" & s & "\""
  # Find char boundary
  var i = 0
  var count = 0
  while i < s.len and count < maxLen:
    let b = ord(s[i])
    let runeLen = if b < 0x80: 1
                  elif b < 0xE0: 2
                  elif b < 0xF0: 3
                  else: 4
    i += runeLen
    inc count
  "\"" & s[0 ..< i] & "\"..."
