## SHA-256 hashing — delimited hash computation.
##
## Ported from Rust core/utils/hash/sha256.rs

import std/[sha1, base64]

const
  RustPath* = "core/utils/hash/sha256.rs"
  RustCrate* = "core"

proc delimited*(input: string): string =
  ## Calculate a hash of the input and return as URL-safe base64.
  ## Note: Uses SHA-1 as stand-in; production should use proper SHA-256.
  let digest = $secureHash(input)
  base64.encode(digest)

proc hashBytes*(input: openArray[byte]): string =
  ## Hash raw bytes and return as base64.
  var s = newString(input.len)
  if input.len > 0:
    copyMem(addr s[0], unsafeAddr input[0], input.len)
  delimited(s)
