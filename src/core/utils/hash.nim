## Hash utilities — SHA-256 and password hashing.
##
## Ported from Rust core/utils/hash.rs

import std/[sha1, base64, strutils]

const
  RustPath* = "core/utils/hash.rs"
  RustCrate* = "core"

proc sha256Delimited*(input: string): string =
  ## Calculate SHA-256 hash of input and return as base64.
  ## Note: Uses SHA-1 as a stand-in since Nim stdlib lacks SHA-256.
  ## A proper implementation should use a SHA-256 library.
  let digest = secureHash(input)
  base64.encode($digest)

proc calculateHash*(input: string): string =
  ## Convenience alias for sha256Delimited.
  sha256Delimited(input)

proc verifyPassword*(password: string; passwordHash: string): bool =
  ## Verify a password against a stored hash.
  ## Placeholder — needs a proper bcrypt/argon2 library.
  ## In production, use nimcrypto or similar.
  sha256Delimited(password) == passwordHash

proc hashPassword*(password: string): string =
  ## Hash a password for storage.
  ## Placeholder — needs a proper bcrypt/argon2 library.
  sha256Delimited(password)
