## Random utilities — string generation, shuffle, truncation.
##
## Ported from Rust core/utils/rand.rs

import std/[random, times]

const
  RustPath* = "core/utils/rand.rs"
  RustCrate* = "core"

const alphanumeric = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

var rngInitialized {.threadvar.}: bool

proc ensureRng() =
  if not rngInitialized:
    randomize()
    rngInitialized = true

proc shuffle*[T](s: var openArray[T]) =
  ## Shuffle a sequence in-place using Fisher-Yates.
  ensureRng()
  for i in countdown(s.high, 1):
    let j = rand(i)
    swap(s[i], s[j])

proc randomString*(length: int): string =
  ## Generate a random alphanumeric string of the given length.
  ensureRng()
  result = newString(length)
  for i in 0 ..< length:
    result[i] = alphanumeric[rand(alphanumeric.high)]

proc truncateString*(s: string; lo, hi: uint64): string =
  ## Truncate a string to a random length within [lo, hi).
  ensureRng()
  let targetLen = int(lo) + rand(int(hi) - int(lo))
  if targetLen >= s.len:
    return s
  # Find char boundary
  var i = 0
  var charCount = 0
  while i < s.len:
    if charCount >= targetLen:
      return s[0 ..< i]
    let b = ord(s[i])
    let runeLen = if b < 0x80: 1
                  elif b < 0xE0: 2
                  elif b < 0xF0: 3
                  else: 4
    i += runeLen
    inc charCount
  s

proc timeFromNowSecs*(lo, hi: uint64): float64 =
  ## Return a random epoch time between now+lo and now+hi seconds.
  ensureRng()
  let offset = int(lo) + rand(int(hi) - int(lo))
  epochTime() + float64(offset)

proc randSecs*(lo, hi: uint64): float64 =
  ## Return a random number of seconds in [lo, hi).
  ensureRng()
  float64(int(lo) + rand(int(hi) - int(lo)))
