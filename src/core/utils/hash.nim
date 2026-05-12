const
  RustPath* = "core/utils/hash.rs"
  RustCrate* = "core"

import core/utils/hash/argon as argon

proc password*(preimage: string): string =
  argon.password(preimage)

proc passwordMatches*(preimage, encoded: string): bool =
  argon.passwordMatches(preimage, encoded)

proc verifyPassword*(preimage, encoded: string) =
  argon.verifyPassword(preimage, encoded)
