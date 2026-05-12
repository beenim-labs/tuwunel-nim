import std/[strutils, sysrand]

const
  RustPath* = "core/utils/hash/argon.rs"
  RustCrate* = "core"
  Version13 = 0x13'u32
  Version10 = 0x10'u32
  DefaultMemoryCost* = 19_456'u32
  DefaultTimeCost* = 2'u32
  DefaultParallelism* = 1'u32
  DefaultHashLength* = 32'u32
  SaltLength = 16
  SyncPoints = 4'u32
  BlockWords = 128
  BlockBytes = 1024
  Blake2bBlockBytes = 128
  Blake2bOutBytes = 64
  PrehashDigestLength = 64
  PrehashSeedLength = 72
  Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

type
  Argon2Kind = enum
    Argon2d = 0
    Argon2i = 1
    Argon2id = 2

  Block = array[BlockWords, uint64]

  Argon2Params = object
    kind: Argon2Kind
    version: uint32
    memoryCost: uint32
    timeCost: uint32
    parallelism: uint32
    hashLength: uint32
    salt: seq[byte]
    digest: seq[byte]

proc bytesFromString(value: string): seq[byte] =
  result = newSeq[byte](value.len)
  for idx, ch in value:
    result[idx] = byte(ord(ch))

proc le32(value: uint32): seq[byte] =
  @[
    byte(value and 0xff'u32),
    byte((value shr 8) and 0xff'u32),
    byte((value shr 16) and 0xff'u32),
    byte((value shr 24) and 0xff'u32)
  ]

proc load64(input: openArray[byte]; offset: int): uint64 =
  result = 0
  for idx in 0 ..< 8:
    result = result or (uint64(input[offset + idx]) shl (idx * 8))

proc store64(value: uint64; output: var openArray[byte]; offset: int) =
  for idx in 0 ..< 8:
    output[offset + idx] = byte((value shr (idx * 8)) and 0xff'u64)

proc bytesToBlock(input: openArray[byte]): Block =
  result = default(Block)
  for idx in 0 ..< BlockWords:
    result[idx] = load64(input, idx * 8)

proc blockToBytes(inputBlock: Block): seq[byte] =
  result = newSeq[byte](BlockBytes)
  for idx, value in inputBlock:
    store64(value, result, idx * 8)

proc rotr64(value: uint64; bits: int): uint64 =
  (value shr bits) or (value shl (64 - bits))

{.push overflowChecks: off.}

proc wrappingAdd(a, b: uint64): uint64 =
  a + b

proc fBlaMka(a, b: uint64): uint64 =
  let product = (a and 0xffff_ffff'u64) * (b and 0xffff_ffff'u64)
  a + b + product + product

proc argonRound(v: var Block; a, b, c, d: int) =
  v[a] = fBlaMka(v[a], v[b])
  v[d] = rotr64(v[d] xor v[a], 32)
  v[c] = fBlaMka(v[c], v[d])
  v[b] = rotr64(v[b] xor v[c], 24)
  v[a] = fBlaMka(v[a], v[b])
  v[d] = rotr64(v[d] xor v[a], 16)
  v[c] = fBlaMka(v[c], v[d])
  v[b] = rotr64(v[b] xor v[c], 63)

proc argonBlakeRound(v: var Block; indexes: array[16, int]) =
  argonRound(v, indexes[0], indexes[4], indexes[8], indexes[12])
  argonRound(v, indexes[1], indexes[5], indexes[9], indexes[13])
  argonRound(v, indexes[2], indexes[6], indexes[10], indexes[14])
  argonRound(v, indexes[3], indexes[7], indexes[11], indexes[15])
  argonRound(v, indexes[0], indexes[5], indexes[10], indexes[15])
  argonRound(v, indexes[1], indexes[6], indexes[11], indexes[12])
  argonRound(v, indexes[2], indexes[7], indexes[8], indexes[13])
  argonRound(v, indexes[3], indexes[4], indexes[9], indexes[14])

proc fillBlock(prevBlock, refBlock: Block; nextBlock: Block; withXor: bool): Block =
  result = default(Block)
  var blockR = default(Block)
  var blockTmp = default(Block)
  for idx in 0 ..< BlockWords:
    blockR[idx] = refBlock[idx] xor prevBlock[idx]
    blockTmp[idx] = blockR[idx]
    if withXor:
      blockTmp[idx] = blockTmp[idx] xor nextBlock[idx]

  for row in 0 ..< 8:
    argonBlakeRound(blockR, [
      16 * row, 16 * row + 1, 16 * row + 2, 16 * row + 3,
      16 * row + 4, 16 * row + 5, 16 * row + 6, 16 * row + 7,
      16 * row + 8, 16 * row + 9, 16 * row + 10, 16 * row + 11,
      16 * row + 12, 16 * row + 13, 16 * row + 14, 16 * row + 15
    ])

  for col in 0 ..< 8:
    argonBlakeRound(blockR, [
      2 * col, 2 * col + 1, 2 * col + 16, 2 * col + 17,
      2 * col + 32, 2 * col + 33, 2 * col + 48, 2 * col + 49,
      2 * col + 64, 2 * col + 65, 2 * col + 80, 2 * col + 81,
      2 * col + 96, 2 * col + 97, 2 * col + 112, 2 * col + 113
    ])

  for idx in 0 ..< BlockWords:
    result[idx] = blockTmp[idx] xor blockR[idx]

const
  Blake2bIv = [
    0x6a09e667f3bcc908'u64, 0xbb67ae8584caa73b'u64,
    0x3c6ef372fe94f82b'u64, 0xa54ff53a5f1d36f1'u64,
    0x510e527fade682d1'u64, 0x9b05688c2b3e6c1f'u64,
    0x1f83d9abfb41bd6b'u64, 0x5be0cd19137e2179'u64
  ]
  Blake2bSigma = [
    [0'u8, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14'u8, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
    [11'u8, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
    [7'u8, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
    [9'u8, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
    [2'u8, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
    [12'u8, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
    [13'u8, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
    [6'u8, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
    [10'u8, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
    [0'u8, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
    [14'u8, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3]
  ]

proc blakeMix(v: var array[16, uint64]; m: array[16, uint64]; round, index, a, b, c, d: int) =
  v[a] = wrappingAdd(wrappingAdd(v[a], v[b]), m[int(Blake2bSigma[round][2 * index])])
  v[d] = rotr64(v[d] xor v[a], 32)
  v[c] = wrappingAdd(v[c], v[d])
  v[b] = rotr64(v[b] xor v[c], 24)
  v[a] = wrappingAdd(wrappingAdd(v[a], v[b]), m[int(Blake2bSigma[round][2 * index + 1])])
  v[d] = rotr64(v[d] xor v[a], 16)
  v[c] = wrappingAdd(v[c], v[d])
  v[b] = rotr64(v[b] xor v[c], 63)

proc blakeCompress(h: var array[8, uint64]; inputBlock: array[Blake2bBlockBytes, byte];
                   counter: uint64; finalBlock: bool) =
  var m = default(array[16, uint64])
  var v = default(array[16, uint64])
  for idx in 0 ..< 16:
    m[idx] = load64(inputBlock, idx * 8)
  for idx in 0 ..< 8:
    v[idx] = h[idx]
    v[idx + 8] = Blake2bIv[idx]
  v[12] = v[12] xor counter
  if finalBlock:
    v[14] = v[14] xor high(uint64)

  for round in 0 ..< 12:
    blakeMix(v, m, round, 0, 0, 4, 8, 12)
    blakeMix(v, m, round, 1, 1, 5, 9, 13)
    blakeMix(v, m, round, 2, 2, 6, 10, 14)
    blakeMix(v, m, round, 3, 3, 7, 11, 15)
    blakeMix(v, m, round, 4, 0, 5, 10, 15)
    blakeMix(v, m, round, 5, 1, 6, 11, 12)
    blakeMix(v, m, round, 6, 2, 7, 8, 13)
    blakeMix(v, m, round, 7, 3, 4, 9, 14)

  for idx in 0 ..< 8:
    h[idx] = h[idx] xor v[idx] xor v[idx + 8]

proc blake2b(input: openArray[byte]; outputLength: int): seq[byte] =
  if outputLength <= 0 or outputLength > Blake2bOutBytes:
    raise newException(ValueError, "invalid Blake2b output length")

  var h = default(array[8, uint64])
  for idx in 0 ..< 8:
    h[idx] = Blake2bIv[idx]
  h[0] = h[0] xor (0x01010000'u64 xor uint64(outputLength))

  var offset = 0
  var counter = 0'u64
  while input.len - offset > Blake2bBlockBytes:
    var chunk = default(array[Blake2bBlockBytes, byte])
    for idx in 0 ..< Blake2bBlockBytes:
      chunk[idx] = input[offset + idx]
    counter = counter + Blake2bBlockBytes.uint64
    blakeCompress(h, chunk, counter, false)
    inc offset, Blake2bBlockBytes

  var final = default(array[Blake2bBlockBytes, byte])
  let remaining = input.len - offset
  for idx in 0 ..< remaining:
    final[idx] = input[offset + idx]
  counter = counter + remaining.uint64
  blakeCompress(h, final, counter, true)

  result = newSeq[byte](Blake2bOutBytes)
  for idx, value in h:
    store64(value, result, idx * 8)
  result.setLen(outputLength)

proc blake2bLong(input: openArray[byte]; outputLength: uint32): seq[byte] =
  if outputLength <= Blake2bOutBytes.uint32:
    var prefixed = le32(outputLength)
    prefixed.add(input)
    return blake2b(prefixed, int(outputLength))

  var prefixed = le32(outputLength)
  prefixed.add(input)
  var current = blake2b(prefixed, Blake2bOutBytes)
  result = @[]
  result.add(current[0 ..< 32])
  var toProduce = int(outputLength) - 32
  while toProduce > Blake2bOutBytes:
    current = blake2b(current, Blake2bOutBytes)
    result.add(current[0 ..< 32])
    dec toProduce, 32
  result.add(blake2b(current, toProduce))

{.pop.}

proc encodeBase64(bytes: openArray[byte]): string =
  result = ""
  var acc = 0'u32
  var accLen = 0
  for value in bytes:
    acc = (acc shl 8) + uint32(value)
    inc accLen, 8
    while accLen >= 6:
      dec accLen, 6
      result.add(Base64Alphabet[int((acc shr accLen) and 0x3f'u32)])
  if accLen > 0:
    result.add(Base64Alphabet[int((acc shl (6 - accLen)) and 0x3f'u32)])

proc decodeBase64(value: string): seq[byte] =
  result = @[]
  var acc = 0'u32
  var accLen = 0
  for ch in value:
    let idx = Base64Alphabet.find(ch)
    if idx < 0:
      raise newException(ValueError, "invalid Argon2 base64")
    acc = (acc shl 6) + uint32(idx)
    inc accLen, 6
    if accLen >= 8:
      dec accLen, 8
      result.add(byte((acc shr accLen) and 0xff'u32))
  if accLen > 4 or (acc and ((1'u32 shl accLen) - 1'u32)) != 0'u32:
    raise newException(ValueError, "invalid Argon2 base64 padding")

proc parseDecimal(value: string): uint32 =
  result = 0
  if value.len == 0 or (value.len > 1 and value[0] == '0'):
    raise newException(ValueError, "invalid Argon2 decimal")
  for ch in value:
    if ch < '0' or ch > '9':
      raise newException(ValueError, "invalid Argon2 decimal")
    result = result * 10'u32 + uint32(ord(ch) - ord('0'))

proc parseHash(encoded: string): Argon2Params =
  result = default(Argon2Params)
  let parts = encoded.split('$')
  if parts.len != 6 or parts[0].len != 0:
    raise newException(ValueError, "malformed Argon2 hash")

  case parts[1]
  of "argon2d":
    result.kind = Argon2d
  of "argon2i":
    result.kind = Argon2i
  of "argon2id":
    result.kind = Argon2id
  else:
    raise newException(ValueError, "unsupported Argon2 variant")

  if not parts[2].startsWith("v="):
    raise newException(ValueError, "missing Argon2 version")
  result.version = parseDecimal(parts[2][2 .. ^1])
  if result.version != Version13 and result.version != Version10:
    raise newException(ValueError, "unsupported Argon2 version")

  for item in parts[3].split(','):
    let keyValue = item.split('=', maxsplit = 1)
    if keyValue.len != 2:
      raise newException(ValueError, "invalid Argon2 parameter")
    case keyValue[0]
    of "m":
      result.memoryCost = parseDecimal(keyValue[1])
    of "t":
      result.timeCost = parseDecimal(keyValue[1])
    of "p":
      result.parallelism = parseDecimal(keyValue[1])
    else:
      raise newException(ValueError, "unknown Argon2 parameter")

  result.salt = decodeBase64(parts[4])
  result.digest = decodeBase64(parts[5])
  result.hashLength = uint32(result.digest.len)

proc validate(params: Argon2Params) =
  if params.hashLength < 4'u32:
    raise newException(ValueError, "Argon2 hash length is too short")
  if params.salt.len < 8:
    raise newException(ValueError, "Argon2 salt is too short")
  if params.memoryCost < 8'u32 * params.parallelism:
    raise newException(ValueError, "Argon2 memory cost is too small")
  if params.timeCost < 1'u32:
    raise newException(ValueError, "Argon2 time cost is too small")
  if params.parallelism < 1'u32:
    raise newException(ValueError, "Argon2 parallelism is too small")

proc initialHash(preimage: openArray[byte]; params: Argon2Params): seq[byte] =
  result = @[]
  result.add(le32(params.parallelism))
  result.add(le32(params.hashLength))
  result.add(le32(params.memoryCost))
  result.add(le32(params.timeCost))
  result.add(le32(params.version))
  result.add(le32(uint32(ord(params.kind))))
  result.add(le32(uint32(preimage.len)))
  result.add(preimage)
  result.add(le32(uint32(params.salt.len)))
  result.add(params.salt)
  result.add(le32(0))
  result.add(le32(0))
  result = blake2b(result, PrehashDigestLength)

proc initFirstBlocks(memory: var seq[Block]; params: Argon2Params; laneLength: uint32;
                     prehash: openArray[byte]) =
  var seed = newSeq[byte](PrehashSeedLength)
  for idx in 0 ..< PrehashDigestLength:
    seed[idx] = prehash[idx]

  for lane in 0 ..< params.parallelism:
    let base = int(lane * laneLength)
    let laneBytes = le32(lane)

    let zeroBytes = le32(0'u32)
    for idx, value in zeroBytes:
      seed[PrehashDigestLength + idx] = value
    for idx, value in laneBytes:
      seed[PrehashDigestLength + 4 + idx] = value
    memory[base] = bytesToBlock(blake2bLong(seed, BlockBytes.uint32))

    let oneBytes = le32(1'u32)
    for idx, value in oneBytes:
      seed[PrehashDigestLength + idx] = value
    memory[base + 1] = bytesToBlock(blake2bLong(seed, BlockBytes.uint32))

proc nextAddresses(addressBlock: var Block; inputBlock: var Block) =
  var zero = default(Block)
  inputBlock[6] = inputBlock[6] + 1'u64
  addressBlock = fillBlock(zero, inputBlock, addressBlock, false)
  addressBlock = fillBlock(zero, addressBlock, addressBlock, false)

proc indexAlpha(passNo, sliceNo, index, segmentLength, laneLength: uint32;
                pseudoRand: uint32; sameLane: bool): uint32 =
  var referenceAreaSize: uint32
  if passNo == 0'u32:
    if sliceNo == 0'u32:
      referenceAreaSize = index - 1'u32
    elif sameLane:
      referenceAreaSize = sliceNo * segmentLength + index - 1'u32
    else:
      referenceAreaSize = sliceNo * segmentLength
      if index == 0'u32:
        dec referenceAreaSize
  elif sameLane:
    referenceAreaSize = laneLength - segmentLength + index - 1'u32
  else:
    referenceAreaSize = laneLength - segmentLength
    if index == 0'u32:
      dec referenceAreaSize

  var relativePosition = uint64(pseudoRand)
  relativePosition = (relativePosition * relativePosition) shr 32
  relativePosition = uint64(referenceAreaSize - 1'u32) -
    ((uint64(referenceAreaSize) * relativePosition) shr 32)

  var startPosition = 0'u32
  if passNo != 0'u32:
    if sliceNo == SyncPoints - 1'u32:
      startPosition = 0
    else:
      startPosition = (sliceNo + 1'u32) * segmentLength

  uint32((uint64(startPosition) + relativePosition) mod uint64(laneLength))

proc fillSegment(memory: var seq[Block]; params: Argon2Params; passNo, lane, sliceNo,
                 memoryBlocks, laneLength, segmentLength: uint32) =
  let dataIndependent = params.kind == Argon2i or
    (params.kind == Argon2id and passNo == 0'u32 and sliceNo < SyncPoints div 2'u32)

  var addressBlock = default(Block)
  var inputBlock = default(Block)
  if dataIndependent:
    inputBlock[0] = passNo
    inputBlock[1] = lane
    inputBlock[2] = sliceNo
    inputBlock[3] = memoryBlocks
    inputBlock[4] = params.timeCost
    inputBlock[5] = uint64(ord(params.kind))

  var startingIndex = 0'u32
  if passNo == 0'u32 and sliceNo == 0'u32:
    startingIndex = 2'u32
    if dataIndependent:
      nextAddresses(addressBlock, inputBlock)

  var currOffset = lane * laneLength + sliceNo * segmentLength + startingIndex
  var prevOffset =
    if currOffset mod laneLength == 0'u32:
      currOffset + laneLength - 1'u32
    else:
      currOffset - 1'u32

  var index = startingIndex
  while index < segmentLength:
    if currOffset mod laneLength == 1'u32:
      prevOffset = currOffset - 1'u32

    var pseudoRand: uint64
    if dataIndependent:
      if index mod BlockWords.uint32 == 0'u32:
        nextAddresses(addressBlock, inputBlock)
      pseudoRand = addressBlock[int(index mod BlockWords.uint32)]
    else:
      pseudoRand = memory[int(prevOffset)][0]

    var refLane = uint32(pseudoRand shr 32) mod params.parallelism
    if passNo == 0'u32 and sliceNo == 0'u32:
      refLane = lane
    let refIndex = indexAlpha(
      passNo,
      sliceNo,
      index,
      segmentLength,
      laneLength,
      uint32(pseudoRand and 0xffff_ffff'u64),
      refLane == lane
    )
    let withXor = params.version != Version10 and passNo != 0'u32
    memory[int(currOffset)] = fillBlock(
      memory[int(prevOffset)],
      memory[int(refLane * laneLength + refIndex)],
      memory[int(currOffset)],
      withXor
    )
    inc index
    inc currOffset
    inc prevOffset

proc rawHash(preimage: openArray[byte]; params: Argon2Params): seq[byte] =
  validate(params)
  let memoryBlocks = SyncPoints * params.parallelism *
    (params.memoryCost div (SyncPoints * params.parallelism))
  let segmentLength = memoryBlocks div (params.parallelism * SyncPoints)
  let laneLength = segmentLength * SyncPoints

  var memory = newSeq[Block](int(memoryBlocks))
  initFirstBlocks(memory, params, laneLength, initialHash(preimage, params))

  for passNo in 0'u32 ..< params.timeCost:
    for sliceNo in 0'u32 ..< SyncPoints:
      for lane in 0'u32 ..< params.parallelism:
        fillSegment(memory, params, passNo, lane, sliceNo, memoryBlocks, laneLength, segmentLength)

  var finalBlock = memory[int(laneLength - 1'u32)]
  for lane in 1'u32 ..< params.parallelism:
    let lastBlock = memory[int(lane * laneLength + laneLength - 1'u32)]
    for idx in 0 ..< BlockWords:
      finalBlock[idx] = finalBlock[idx] xor lastBlock[idx]

  blake2bLong(blockToBytes(finalBlock), params.hashLength)

proc constantTimeEqual(left, right: openArray[byte]): bool =
  if left.len != right.len:
    return false
  var diff = 0'u8
  for idx in 0 ..< left.len:
    diff = diff or (left[idx] xor right[idx])
  diff == 0'u8

proc hashWithSalt*(preimage: string; salt: openArray[byte];
                   memoryCost: uint32 = DefaultMemoryCost;
                   timeCost: uint32 = DefaultTimeCost;
                   parallelism: uint32 = DefaultParallelism;
                   hashLength: uint32 = DefaultHashLength): string =
  var params = Argon2Params(
    kind: Argon2id,
    version: Version13,
    memoryCost: memoryCost,
    timeCost: timeCost,
    parallelism: parallelism,
    hashLength: hashLength,
    salt: @salt
  )
  let digest = rawHash(bytesFromString(preimage), params)
  "$argon2id$v=19$m=" & $params.memoryCost & ",t=" & $params.timeCost & ",p=" &
    $params.parallelism & "$" & encodeBase64(params.salt) & "$" & encodeBase64(digest)

proc hashWithSalt*(preimage, salt: string;
                   memoryCost: uint32 = DefaultMemoryCost;
                   timeCost: uint32 = DefaultTimeCost;
                   parallelism: uint32 = DefaultParallelism;
                   hashLength: uint32 = DefaultHashLength): string =
  hashWithSalt(preimage, bytesFromString(salt), memoryCost, timeCost, parallelism, hashLength)

proc password*(preimage: string): string =
  var salt = default(array[SaltLength, byte])
  if not urandom(salt):
    raise newException(IOError, "failed to generate Argon2 salt")
  hashWithSalt(preimage, salt)

proc passwordMatches*(preimage, encoded: string): bool =
  var params = parseHash(encoded)
  let expected = params.digest
  let computed = rawHash(bytesFromString(preimage), params)
  constantTimeEqual(computed, expected)

proc verifyPassword*(preimage, encoded: string) =
  if not passwordMatches(preimage, encoded):
    raise newException(ValueError, "unverified")
