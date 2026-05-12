import std/unittest

import core/utils/hash/sha256 as sha256_utils

suite "sha256 utility parity":
  test "hash matches standard SHA-256 vectors":
    check sha256_utils.hash("").toHex() ==
      "e3b0c44298fc1c149afbf4c8996fb924" &
      "27ae41e4649b934ca495991b7852b855"
    check sha256_utils.hash("abc").toHex() ==
      "ba7816bf8f01cfea414140de5dae2223" &
      "b00361a396177a9cb410ff61f20015ad"

  test "concat and delimited gather inputs like Rust":
    check sha256_utils.concat(["ab", "c"]).toHex() == sha256_utils.hash("abc").toHex()
    check sha256_utils.delimited(["ab", "c"]).toHex() ==
      sha256_utils.hash("ab" & char(0xff) & "c").toHex()
    check sha256_utils.delimited([]).toHex() == sha256_utils.hash("").toHex()

  test "digest byte string preserves 32 raw bytes":
    let bytes = sha256_utils.hash("abc").toBytesString()
    check bytes.len == 32
    check ord(bytes[0]) == 0xba
