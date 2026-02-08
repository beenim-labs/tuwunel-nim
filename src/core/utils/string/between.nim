## String submodule — Between extractor.
##
## Ported from Rust core/utils/string/between.rs

const
  RustPath* = "core/utils/string/between.rs"
  RustCrate* = "core"

proc between*(s: string; left: char; right: char): string =
  ## Extract the substring between two delimiters.
  ## Returns empty string if delimiters not found.
  let leftPos = s.find(left)
  if leftPos < 0:
    return ""
  let rightPos = s.find(right, leftPos + 1)
  if rightPos < 0:
    return ""
  s[leftPos + 1 ..< rightPos]

proc betweenStr*(s: string; left: string; right: string): string =
  ## Extract the substring between two string delimiters.
  let leftPos = s.find(left)
  if leftPos < 0:
    return ""
  let start = leftPos + left.len
  let rightPos = s.find(right, start)
  if rightPos < 0:
    return ""
  s[start ..< rightPos]

import std/strutils
