## Argon2 password hashing — password verification and generation.
##
## Ported from Rust core/utils/hash/argon.rs
## Placeholder — needs a proper argon2 library for production use.

import std/[sha1, base64]

const
  RustPath* = "core/utils/hash/argon.rs"
  RustCrate* = "core"

proc verifyPassword*(password: string; hash: string): bool =
  ## Verify a password against a stored hash.
  ## Placeholder using SHA-1 — use nimcrypto/argon2 in production.
  let computed = base64.encode($secureHash(password))
  computed == hash

proc password*(password: string): string =
  ## Hash a password for storage.
  ## Placeholder — use argon2 in production.
  base64.encode($secureHash(password))
