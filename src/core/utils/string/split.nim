## String submodule — split utilities.
##
## Ported from Rust core/utils/string/split.rs

import std/strutils

const
  RustPath* = "core/utils/string/split.rs"
  RustCrate* = "core"

iterator splitInfallible*(s: string; sep: char): string =
  ## Split a string by a character separator, yielding each part.
  ## Unlike Nim's split, this never returns empty strings.
  for part in s.split(sep):
    if part.len > 0:
      yield part

iterator splitInfallibleStr*(s: string; sep: string): string =
  ## Split a string by a string separator, skipping empty parts.
  for part in s.split(sep):
    if part.len > 0:
      yield part

proc splitOnce*(s: string; sep: char): (string, string) =
  ## Split a string at the first occurrence of sep, returning both halves.
  let pos = s.find(sep)
  if pos < 0:
    (s, "")
  else:
    (s[0 ..< pos], s[pos + 1 ..< s.len])

proc splitOnceStr*(s: string; sep: string): (string, string) =
  ## Split a string at the first occurrence of sep string.
  let pos = s.find(sep)
  if pos < 0:
    (s, "")
  else:
    (s[0 ..< pos], s[pos + sep.len ..< s.len])
