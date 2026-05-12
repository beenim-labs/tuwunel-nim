import std/[strutils, unittest]

import core/utils/hash as hash_utils
import core/utils/hash/argon as argon_utils

suite "argon password hashing parity":
  test "known Argon2id vector matches Rust defaults":
    let salt = "1234567890123456"
    let digest = argon_utils.hashWithSalt("temp123", salt)
    check digest ==
      "$argon2id$v=19$m=19456,t=2,p=1$MTIzNDU2Nzg5MDEyMzQ1Ng$" &
      "RQkVLif5SW+I/7vKD46LfJ0U6e3HFVA/2TOxG+mPMOk"
    check hash_utils.passwordMatches("temp123", digest)
    check not hash_utils.passwordMatches("temp321", digest)

  test "random password hashes verify through top-level hash module":
    let digest = hash_utils.password("temp123")
    check digest.startsWith("$argon2id$v=19$m=19456,t=2,p=1$")
    check hash_utils.passwordMatches("temp123", digest)
    check not hash_utils.passwordMatches("wrong", digest)

  test "verify_password mirrors Rust-style error behavior":
    let digest = argon_utils.hashWithSalt("temp123", "abcdefghijklmnop")
    hash_utils.verify_password("temp123", digest)
    expect ValueError:
      hash_utils.verify_password("temp321", digest)
