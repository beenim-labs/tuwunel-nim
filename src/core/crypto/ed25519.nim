import std/sysrand

const
  RustPath* = "service/server_keys/keypair.rs"
  RustCrate* = "service"
  Ed25519PrivateSeedLen* = 32
  Ed25519PublicKeyLen* = 32
  Ed25519SignatureLen* = 64
  EvpPkeyEd25519 = 1087

when defined(macosx):
  const CryptoLib = "(/opt/homebrew/opt/openssl@3/lib/libcrypto.3.dylib|/usr/local/opt/openssl@3/lib/libcrypto.3.dylib|libcrypto.3.dylib)"
elif defined(windows):
  const CryptoLib = "(libcrypto-3-x64|libcrypto-3|libcrypto-1_1-x64).dll"
else:
  const CryptoLib = "libcrypto.so(.3|)"

type
  SslStruct {.final, pure.} = object
  EvpPkey = ptr SslStruct
  EvpMdCtx = ptr SslStruct
  EvpPkeyCtx = ptr SslStruct
  Engine = ptr SslStruct
  EvpMd = ptr SslStruct

  Ed25519Keypair* = object
    seed*: seq[byte]
    publicKey*: seq[byte]

proc EVP_PKEY_new_raw_private_key(
    kind: cint;
    engine: Engine;
    key: ptr uint8;
    keyLen: csize_t
): EvpPkey {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_PKEY_new_raw_public_key(
    kind: cint;
    engine: Engine;
    key: ptr uint8;
    keyLen: csize_t
): EvpPkey {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_PKEY_get_raw_public_key(
    pkey: EvpPkey;
    publicKey: ptr uint8;
    publicKeyLen: ptr csize_t
): cint {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_PKEY_free(pkey: EvpPkey) {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_MD_CTX_new(): EvpMdCtx {.cdecl, dynlib: CryptoLib, importc.}
proc EVP_MD_CTX_free(ctx: EvpMdCtx) {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_DigestSignInit(
    ctx: EvpMdCtx;
    pctx: ptr EvpPkeyCtx;
    digestType: EvpMd;
    engine: Engine;
    pkey: EvpPkey
): cint {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_DigestSign(
    ctx: EvpMdCtx;
    sigret: ptr uint8;
    siglen: ptr csize_t;
    tbs: ptr uint8;
    tbslen: csize_t
): cint {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_DigestVerifyInit(
    ctx: EvpMdCtx;
    pctx: ptr EvpPkeyCtx;
    digestType: EvpMd;
    engine: Engine;
    pkey: EvpPkey
): cint {.cdecl, dynlib: CryptoLib, importc.}

proc EVP_DigestVerify(
    ctx: EvpMdCtx;
    sigret: ptr uint8;
    siglen: csize_t;
    tbs: ptr uint8;
    tbslen: csize_t
): cint {.cdecl, dynlib: CryptoLib, importc.}

proc bytesPtr(data: openArray[byte]): ptr uint8 =
  if data.len == 0:
    cast[ptr uint8](nil)
  else:
    cast[ptr uint8](unsafeAddr data[0])

proc messagePtr(message: string): ptr uint8 =
  if message.len == 0:
    cast[ptr uint8](nil)
  else:
    cast[ptr uint8](unsafeAddr message[0])

proc keyFromSeed(seed: openArray[byte]): tuple[ok: bool, pkey: EvpPkey, err: string] =
  if seed.len != Ed25519PrivateSeedLen:
    return (false, nil, "Ed25519 private seed must be 32 bytes")
  let pkey = EVP_PKEY_new_raw_private_key(
    EvpPkeyEd25519.cint,
    nil,
    bytesPtr(seed),
    csize_t(seed.len),
  )
  if pkey == nil:
    return (false, nil, "EVP_PKEY_new_raw_private_key failed")
  (true, pkey, "")

proc publicKeyFromSeed*(seed: openArray[byte]): tuple[ok: bool, publicKey: seq[byte], err: string] =
  let key = keyFromSeed(seed)
  if not key.ok:
    return (false, @[], key.err)
  defer: EVP_PKEY_free(key.pkey)

  var publicKey = newSeq[byte](Ed25519PublicKeyLen)
  var publicKeyLen = csize_t(publicKey.len)
  if EVP_PKEY_get_raw_public_key(key.pkey, addr publicKey[0], addr publicKeyLen) != 1:
    return (false, @[], "EVP_PKEY_get_raw_public_key failed")
  if int(publicKeyLen) != Ed25519PublicKeyLen:
    return (false, @[], "OpenSSL returned invalid Ed25519 public-key length")
  (true, publicKey, "")

proc generateKeypair*(): tuple[ok: bool, keypair: Ed25519Keypair, err: string] =
  var seed = urandom(Ed25519PrivateSeedLen)
  if seed.len != Ed25519PrivateSeedLen:
    return (false, Ed25519Keypair(), "failed to read OS random seed")
  let publicKey = publicKeyFromSeed(seed)
  if not publicKey.ok:
    return (false, Ed25519Keypair(), publicKey.err)
  (true, Ed25519Keypair(seed: seed, publicKey: publicKey.publicKey), "")

proc sign*(seed: openArray[byte]; message: string): tuple[ok: bool, signature: seq[byte], err: string] =
  let key = keyFromSeed(seed)
  if not key.ok:
    return (false, @[], key.err)
  defer: EVP_PKEY_free(key.pkey)

  let ctx = EVP_MD_CTX_new()
  if ctx == nil:
    return (false, @[], "EVP_MD_CTX_new failed")
  defer: EVP_MD_CTX_free(ctx)

  if EVP_DigestSignInit(ctx, nil, nil, nil, key.pkey) != 1:
    return (false, @[], "EVP_DigestSignInit failed")

  var signatureLen: csize_t = 0
  if EVP_DigestSign(ctx, nil, addr signatureLen, messagePtr(message), csize_t(message.len)) != 1:
    return (false, @[], "EVP_DigestSign size probe failed")
  if int(signatureLen) != Ed25519SignatureLen:
    return (false, @[], "OpenSSL returned invalid Ed25519 signature length")

  var signature = newSeq[byte](int(signatureLen))
  if EVP_DigestSign(ctx, addr signature[0], addr signatureLen, messagePtr(message), csize_t(message.len)) != 1:
    return (false, @[], "EVP_DigestSign failed")
  if int(signatureLen) != signature.len:
    signature.setLen(int(signatureLen))
  (true, signature, "")

proc verify*(
    publicKey: openArray[byte];
    message: string;
    signature: openArray[byte]
): bool =
  if publicKey.len != Ed25519PublicKeyLen or signature.len != Ed25519SignatureLen:
    return false

  let pkey = EVP_PKEY_new_raw_public_key(
    EvpPkeyEd25519.cint,
    nil,
    bytesPtr(publicKey),
    csize_t(publicKey.len),
  )
  if pkey == nil:
    return false
  defer: EVP_PKEY_free(pkey)

  let ctx = EVP_MD_CTX_new()
  if ctx == nil:
    return false
  defer: EVP_MD_CTX_free(ctx)

  if EVP_DigestVerifyInit(ctx, nil, nil, nil, pkey) != 1:
    return false

  EVP_DigestVerify(
    ctx,
    bytesPtr(signature),
    csize_t(signature.len),
    messagePtr(message),
    csize_t(message.len),
  ) == 1
