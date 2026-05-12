import std/[options, strutils, unicode]

type NativeString = system.string

const
  RustPath* = "core/utils/string.rs"
  RustCrate* = "core"
  Empty* = ""

proc isFormatLiteral*(s: NativeString): bool =
  "{" in s and "}" in s

proc collectStream*(writer: proc(outp: var NativeString): bool): tuple[ok: bool, value: NativeString] =
  var outp = ""
  if writer(outp):
    (true, outp)
  else:
    (false, outp)

proc camelToSnakeString*(s: NativeString): NativeString =
  result = ""
  var previousWasLowerOrOther = false
  for ch in s:
    let isUpper = ch in {'A'..'Z'}
    if isUpper and previousWasLowerOrOther:
      result.add('_')
    if isUpper:
      result.add(chr(ord(ch) + ord('a') - ord('A')))
    else:
      result.add(ch)
    previousWasLowerOrOther = not isUpper

proc commonPrefix*(choices: openArray[NativeString]): NativeString =
  if choices.len == 0:
    return Empty
  result = choices[0]
  if choices.len > 1:
    for idx in 1 .. choices.high:
      let choice = choices[idx]
      var prefixLen = 0
      let maxLen = min(result.len, choice.len)
      while prefixLen < maxLen and result[prefixLen] == choice[prefixLen]:
        inc prefixLen
      result.setLen(prefixLen)
      if result.len == 0:
        return

proc byteSum(s: NativeString): int =
  result = 0
  for ch in s:
    result = result + ord(ch)

proc truncateAtCharCount(s: NativeString; count: int): NativeString =
  if count <= 0:
    return Empty
  var seen = 0
  for byteIndex, _ in s:
    if seen == count:
      return s[0 ..< byteIndex]
    inc seen
  s

proc truncateDeterministic*(s: NativeString; start = 0; stop = -1): NativeString =
  let stopValue = if stop < 0: s.len else: stop
  let boundedStop = max(start, stopValue)
  let moduloBase = max(s.len, 1)
  let rawLen = byteSum(s) mod moduloBase
  let charCount = min(max(rawLen, start), boundedStop)
  truncateAtCharCount(s, charCount)

proc splitOnceInfallible*(s, delim: NativeString): tuple[left: NativeString, right: NativeString] =
  let idx = s.find(delim)
  if idx < 0:
    return (s, Empty)
  (s[0 ..< idx], s[(idx + delim.len) .. ^1])

proc rsplitOnceInfallible*(s, delim: NativeString): tuple[left: NativeString, right: NativeString] =
  let idx = s.rfind(delim)
  if idx < 0:
    return (s, Empty)
  (s[0 ..< idx], s[(idx + delim.len) .. ^1])

proc between*(s, leftDelim, rightDelim: NativeString): Option[NativeString] =
  let left = s.find(leftDelim)
  if left < 0:
    return none(system.string)
  let start = left + leftDelim.len
  let right = s.rfind(rightDelim)
  if right < start:
    return none(system.string)
  some(s[start ..< right])

proc betweenInfallible*(s, leftDelim, rightDelim: NativeString): NativeString =
  let found = between(s, leftDelim, rightDelim)
  if found.isSome:
    found.get()
  else:
    s

proc isQuoted*(s: NativeString): bool =
  s.len >= 2 and s[0] == '"' and s[^1] == '"'

proc unquote*(s: NativeString): Option[NativeString] =
  if s.isQuoted:
    some(s[1 ..< s.high])
  else:
    none(system.string)

proc unquoteInfallible*(s: NativeString): NativeString =
  result = s
  if result.startsWith("\""):
    result = result[1 .. ^1]
  if result.endsWith("\""):
    result = result[0 ..< result.high]

proc stringFromBytes*(bytes: openArray[byte]): tuple[ok: bool, value: NativeString] =
  var s = newString(bytes.len)
  for i, b in bytes:
    s[i] = char(b)
  if validateUtf8(s) == -1:
    (true, s)
  else:
    (false, Empty)

proc strFromBytes*(bytes: openArray[byte]): tuple[ok: bool, value: NativeString] =
  stringFromBytes(bytes)

proc toLowercase*(s: NativeString): NativeString =
  s.toLowerAscii()
