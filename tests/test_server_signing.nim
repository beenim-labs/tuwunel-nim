import std/[json, unittest]

import core/crypto/ed25519
import core/matrix/server_signing
import api/server/key as server_key_api
import service/server_keys/keypair as server_keypair
import service/server_keys/sign as server_key_sign
import service/server_keys/verify as server_key_verify

proc fixedSeed(): seq[byte] =
  result = newSeq[byte](Ed25519PrivateSeedLen)
  for idx in 0 ..< result.len:
    result[idx] = byte(idx)

suite "Matrix server signing":
  test "Ed25519 primitive derives public keys and verifies signatures":
    let seed = fixedSeed()
    let publicKey = publicKeyFromSeed(seed)
    check publicKey.ok

    let signature = sign(seed, "matrix canonical payload")
    check signature.ok
    check verify(publicKey.publicKey, "matrix canonical payload", signature.signature)
    check not verify(publicKey.publicKey, "changed payload", signature.signature)

  test "server key payload is signed over Matrix canonical JSON":
    let seed = fixedSeed()
    let publicKey = publicKeyFromSeed(seed)
    check publicKey.ok

    let payload = signedServerKeysPayload(
      "localhost",
      "ed25519:test",
      seed,
      publicKey.publicKey,
      123456789'i64,
    )
    check payload.ok
    check payload.payload["server_name"].getStr("") == "localhost"
    check payload.payload["verify_keys"]["ed25519:test"]["key"].getStr("").len > 0
    check payload.payload["signatures"]["localhost"]["ed25519:test"].getStr("") !=
      "native-nim-placeholder-signature"

    let canonical = canonicalSigningString(payload.payload)
    check canonical.ok

    let decoded = decodeUnpaddedBase64(
      payload.payload["signatures"]["localhost"]["ed25519:test"].getStr("")
    )
    check decoded.ok
    check verify(publicKey.publicKey, canonical.value, decoded.data)

    var tampered = payload.payload.copy()
    tampered["valid_until_ts"] = %123456790
    let tamperedCanonical = canonicalSigningString(tampered)
    check tamperedCanonical.ok
    check not verify(publicKey.publicKey, tamperedCanonical.value, decoded.data)

  test "server key service modules expose Rust-shaped keypair signing and verification":
    let keypair = server_keypair.keypairFromSeed("ed25519:test", fixedSeed())
    check keypair.ok
    check keypair.keypair.encodedPublicKey().len == 43
    check keypair.keypair.encodedSeed().len == 43

    let signed = server_key_api.serverKeysPayload(
      "localhost",
      keypair.keypair.keyId,
      keypair.keypair.seed,
      keypair.keypair.publicKey,
      123456789'i64,
    )
    check signed.ok
    check server_key_verify.verifyJsonSignature(
      signed.payload,
      "localhost",
      keypair.keypair.keyId,
      keypair.keypair.publicKey,
    )

    let customSigned = server_key_sign.signJsonWithKeypair(
      %*{"server_name": "localhost", "valid_until_ts": 123456789},
      "localhost",
      keypair.keypair,
    )
    check customSigned.ok
    check server_key_verify.verifyJsonSignature(
      customSigned.payload,
      "localhost",
      keypair.keypair.keyId,
      keypair.keypair.publicKey,
    )
