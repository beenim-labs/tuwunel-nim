import std/strutils

import core/crypto/ed25519
import core/matrix/server_signing

const
  RustPath* = "service/server_keys/keypair.rs"
  RustCrate* = "service"

type
  ServerSigningKeypair* = object
    keyId*: string
    seed*: seq[byte]
    publicKey*: seq[byte]

proc keypairFromSeed*(
    keyId: string;
    seed: openArray[byte]
): tuple[ok: bool, keypair: ServerSigningKeypair, err: string] =
  if keyId.len == 0 or not keyId.startsWith("ed25519:"):
    return (false, ServerSigningKeypair(), "server signing key id must start with ed25519:")
  if seed.len != Ed25519PrivateSeedLen:
    return (false, ServerSigningKeypair(), "server signing key seed must be 32 bytes")

  let publicKey = publicKeyFromSeed(seed)
  if not publicKey.ok:
    return (false, ServerSigningKeypair(), publicKey.err)

  var storedSeed = newSeq[byte](seed.len)
  for idx, value in seed:
    storedSeed[idx] = value

  (
    true,
    ServerSigningKeypair(
      keyId: keyId,
      seed: storedSeed,
      publicKey: publicKey.publicKey,
    ),
    "",
  )

proc generateKeypair*(
    keyId: string
): tuple[ok: bool, keypair: ServerSigningKeypair, err: string] =
  let generated = ed25519.generateKeypair()
  if not generated.ok:
    return (false, ServerSigningKeypair(), generated.err)

  (
    true,
    ServerSigningKeypair(
      keyId: keyId,
      seed: generated.keypair.seed,
      publicKey: generated.keypair.publicKey,
    ),
    "",
  )

proc encodedPublicKey*(keypair: ServerSigningKeypair): string =
  encodeUnpaddedBase64(keypair.publicKey)

proc encodedSeed*(keypair: ServerSigningKeypair): string =
  encodeUnpaddedBase64(keypair.seed)
