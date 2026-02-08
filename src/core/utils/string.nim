## String utilities — camelCase conversion, common prefix, byte parsing.
##
## Ported from Rust core/utils/string.rs

import std/[unicode, strutils]

const
  RustPath* = "core/utils/string.rs"
  RustCrate* = "core"

const EMPTY* = ""

proc camelToSnakeCase*(s: string): string =
  ## Convert a camelCase or PascalCase string to snake_case.
  if s.len == 0:
    return ""
  result = newStringOfCap(s.len + s.len div 4)
  var prevWasUpper = false
  for i, ch in s:
    let isUpper = ch in 'A'..'Z'
    if isUpper and i > 0 and not prevWasUpper:
      result.add '_'
    result.add ch.toLowerAscii()
    prevWasUpper = not isUpper

proc commonPrefix*(choices: openArray[string]): string =
  ## Find the common prefix from a collection of strings.
  ## Example: commonPrefix(["conduwuit", "conduit", "construct"]) == "con"
  if choices.len == 0:
    return ""
  result = choices[0]
  for i in 1 ..< choices.len:
    var commonLen = 0
    let minLen = min(result.len, choices[i].len)
    while commonLen < minLen and result[commonLen] == choices[i][commonLen]:
      inc commonLen
    result = result[0 ..< commonLen]
    if result.len == 0:
      return ""

proc stringFromBytes*(bytes: openArray[byte]): string =
  ## Parse bytes into a string (UTF-8).
  result = newString(bytes.len)
  if bytes.len > 0:
    copyMem(addr result[0], unsafeAddr bytes[0], bytes.len)

proc strFromBytes*(bytes: openArray[byte]): string =
  ## Parse bytes into a string (UTF-8). Alias for stringFromBytes.
  stringFromBytes(bytes)

proc truncateDeterministic*(s: string; rangeStart, rangeEnd: int): string =
  ## Truncate a string deterministically based on byte-sum modulo.
  if s.len == 0:
    return s
  var byteSum = 0
  for b in s:
    byteSum = byteSum + ord(b)
  let targetLen = clamp(byteSum mod max(s.len, 1), rangeStart, rangeEnd)
  if targetLen >= s.len:
    return s
  # Find char boundary
  var i = 0
  var charCount = 0
  for rune in s.runes:
    if charCount >= targetLen:
      return s[0 ..< i]
    i += rune.size
    inc charCount
  s

proc collectStream*(cb: proc(writer: var string)) : string =
  ## Collect output from a callback that writes to a string.
  result = ""
  cb(result)
