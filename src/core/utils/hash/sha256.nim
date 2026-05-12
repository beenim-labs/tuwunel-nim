const
  RustPath* = "core/utils/hash/sha256.rs"
  RustCrate* = "core"

type Digest* = array[32, byte]

proc rotr32(x: uint32; n: int): uint32 =
  (x shr n) or (x shl (32 - n))

proc add32(a, b: uint32): uint32 =
  uint32((uint64(a) + uint64(b)) and 0xffffffff'u64)

proc bytesFromString(input: string): seq[byte] =
  result = newSeq[byte](input.len)
  for idx, ch in input:
    result[idx] = byte(ord(ch))

proc digestBytes(input: openArray[byte]): Digest =
  const k = [
    0x428a2f98'u32, 0x71374491'u32, 0xb5c0fbcf'u32, 0xe9b5dba5'u32,
    0x3956c25b'u32, 0x59f111f1'u32, 0x923f82a4'u32, 0xab1c5ed5'u32,
    0xd807aa98'u32, 0x12835b01'u32, 0x243185be'u32, 0x550c7dc3'u32,
    0x72be5d74'u32, 0x80deb1fe'u32, 0x9bdc06a7'u32, 0xc19bf174'u32,
    0xe49b69c1'u32, 0xefbe4786'u32, 0x0fc19dc6'u32, 0x240ca1cc'u32,
    0x2de92c6f'u32, 0x4a7484aa'u32, 0x5cb0a9dc'u32, 0x76f988da'u32,
    0x983e5152'u32, 0xa831c66d'u32, 0xb00327c8'u32, 0xbf597fc7'u32,
    0xc6e00bf3'u32, 0xd5a79147'u32, 0x06ca6351'u32, 0x14292967'u32,
    0x27b70a85'u32, 0x2e1b2138'u32, 0x4d2c6dfc'u32, 0x53380d13'u32,
    0x650a7354'u32, 0x766a0abb'u32, 0x81c2c92e'u32, 0x92722c85'u32,
    0xa2bfe8a1'u32, 0xa81a664b'u32, 0xc24b8b70'u32, 0xc76c51a3'u32,
    0xd192e819'u32, 0xd6990624'u32, 0xf40e3585'u32, 0x106aa070'u32,
    0x19a4c116'u32, 0x1e376c08'u32, 0x2748774c'u32, 0x34b0bcb5'u32,
    0x391c0cb3'u32, 0x4ed8aa4a'u32, 0x5b9cca4f'u32, 0x682e6ff3'u32,
    0x748f82ee'u32, 0x78a5636f'u32, 0x84c87814'u32, 0x8cc70208'u32,
    0x90befffa'u32, 0xa4506ceb'u32, 0xbef9a3f7'u32, 0xc67178f2'u32
  ]

  var h = [
    0x6a09e667'u32, 0xbb67ae85'u32, 0x3c6ef372'u32, 0xa54ff53a'u32,
    0x510e527f'u32, 0x9b05688c'u32, 0x1f83d9ab'u32, 0x5be0cd19'u32
  ]
  result = default(Digest)
  var msg = newSeq[byte](input.len)
  for idx, value in input:
    msg[idx] = value
  let bitLen = uint64(input.len) * 8'u64
  msg.add(0x80'u8)
  while (msg.len mod 64) != 56:
    msg.add(0'u8)
  for shift in countdown(56, 0, 8):
    msg.add(byte((bitLen shr shift) and 0xff'u64))

  var w: array[64, uint32] = default(array[64, uint32])
  var offset = 0
  while offset < msg.len:
    for idx in 0 ..< 16:
      let j = offset + idx * 4
      w[idx] = (uint32(msg[j]) shl 24) or (uint32(msg[j + 1]) shl 16) or
        (uint32(msg[j + 2]) shl 8) or uint32(msg[j + 3])
    for idx in 16 ..< 64:
      let s0 = rotr32(w[idx - 15], 7) xor rotr32(w[idx - 15], 18) xor (w[idx - 15] shr 3)
      let s1 = rotr32(w[idx - 2], 17) xor rotr32(w[idx - 2], 19) xor (w[idx - 2] shr 10)
      w[idx] = add32(add32(add32(w[idx - 16], s0), w[idx - 7]), s1)

    var a = h[0]
    var b = h[1]
    var c = h[2]
    var d = h[3]
    var e = h[4]
    var f = h[5]
    var g = h[6]
    var hh = h[7]
    for idx in 0 ..< 64:
      let s1 = rotr32(e, 6) xor rotr32(e, 11) xor rotr32(e, 25)
      let ch = (e and f) xor ((not e) and g)
      let temp1 = add32(add32(add32(add32(hh, s1), ch), k[idx]), w[idx])
      let s0 = rotr32(a, 2) xor rotr32(a, 13) xor rotr32(a, 22)
      let maj = (a and b) xor (a and c) xor (b and c)
      let temp2 = add32(s0, maj)
      hh = g
      g = f
      f = e
      e = add32(d, temp1)
      d = c
      c = b
      b = a
      a = add32(temp1, temp2)

    h[0] = add32(h[0], a)
    h[1] = add32(h[1], b)
    h[2] = add32(h[2], c)
    h[3] = add32(h[3], d)
    h[4] = add32(h[4], e)
    h[5] = add32(h[5], f)
    h[6] = add32(h[6], g)
    h[7] = add32(h[7], hh)
    inc offset, 64

  for idx, value in h:
    result[idx * 4] = byte((value shr 24) and 0xff'u32)
    result[idx * 4 + 1] = byte((value shr 16) and 0xff'u32)
    result[idx * 4 + 2] = byte((value shr 8) and 0xff'u32)
    result[idx * 4 + 3] = byte(value and 0xff'u32)

proc hashBytes*(input: openArray[byte]): Digest =
  digestBytes(input)

proc hash*(input: string): Digest =
  digestBytes(bytesFromString(input))

proc concat*(inputs: openArray[string]): Digest =
  var gathered: seq[byte] = @[]
  for input in inputs:
    gathered.add(bytesFromString(input))
  digestBytes(gathered)

proc delimited*(inputs: openArray[string]): Digest =
  var gathered: seq[byte] = @[]
  for idx, input in inputs:
    if idx > 0:
      gathered.add(0xff'u8)
    gathered.add(bytesFromString(input))
  digestBytes(gathered)

proc toBytesString*(digest: Digest): string =
  result = newString(digest.len)
  for idx, value in digest:
    result[idx] = char(value)

proc toHex*(digest: Digest): string =
  const alphabet = "0123456789abcdef"
  result = newString(digest.len * 2)
  for idx, value in digest:
    result[idx * 2] = alphabet[int(value shr 4)]
    result[idx * 2 + 1] = alphabet[int(value and 0x0f)]
