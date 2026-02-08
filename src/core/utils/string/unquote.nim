## String submodule — unquote and unquoted utilities.
##
## Ported from Rust core/utils/string/unquote.rs and unquoted.rs

import std/strutils

const
  RustPath* = "core/utils/string/unquote.rs"
  RustCrate* = "core"

proc unquote*(s: string): string =
  ## Remove surrounding quotes from a string, if present.
  if s.len >= 2:
    if (s[0] == '"' and s[^1] == '"') or (s[0] == '\'' and s[^1] == '\''):
      return s[1 ..< s.len - 1]
  s

proc unquoted*(s: string): string =
  ## Remove all quote characters from a string.
  result = ""
  for ch in s:
    if ch != '"' and ch != '\'':
      result.add ch

proc isQuoted*(s: string): bool =
  ## Check if a string is surrounded by quotes.
  s.len >= 2 and
    ((s[0] == '"' and s[^1] == '"') or (s[0] == '\'' and s[^1] == '\''))
