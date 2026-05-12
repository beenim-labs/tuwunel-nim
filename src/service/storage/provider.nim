const
  RustPath* = "service/storage/provider.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[algorithm, httpclient, os, strutils, times, uri, xmlparser, xmltree]

type
  StorageProviderKind* = enum
    spLocal
    spS3

  CopyMode* = enum
    cmOverwrite
    cmCreate

  StorageProviderConfig* = object
    kind*: StorageProviderKind
    name*: string
    basePath*: string
    bucket*: string
    endpoint*: string
    region*: string
    key*: string
    token*: string
    useHttps*: bool
    useSignatures*: bool
    usePayloadSignatures*: bool
    useVhostRequest*: bool
    createIfMissing*: bool
    deleteEmptyDirectories*: bool
    startupCheck*: bool
    multipartThreshold*: int
    multipartPartSize*: int

  ObjectMeta* = object
    location*: string
    size*: int64
    modifiedUnix*: int64

  PutResult* = object
    location*: string
    size*: int64

  Provider* = ref object
    name*: string
    config*: StorageProviderConfig
    basePath*: string
    s3Endpoint*: string
    s3EndpointPath*: string
    s3Bucket*: string
    s3Region*: string
    s3Key*: string
    s3Secret*: string
    s3Token*: string
    s3UseHttps*: bool
    s3UseSignatures*: bool
    s3UsePayloadSignatures*: bool
    s3UseVhostRequest*: bool

  HeaderPair = object
    name: string
    value: string

  S3Request = object
    url: string
    canonicalUri: string
    canonicalQuery: string
    host: string
    headers: seq[HeaderPair]

proc defaultMultipartValue(value: int): int =
  if value > 0: value else: high(int)

proc rotr32(x: uint32; n: int): uint32 =
  (x shr n) or (x shl (32 - n))

proc add32(a, b: uint32): uint32 =
  uint32((uint64(a) + uint64(b)) and 0xffffffff'u64)

proc sha256Digest(data: string): array[32, byte] =
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
  result = default(array[32, byte])
  var msg = newSeq[byte](data.len)
  for i, ch in data:
    msg[i] = byte(ord(ch))
  let bitLen = uint64(data.len) * 8'u64
  msg.add(0x80'u8)
  while (msg.len mod 64) != 56:
    msg.add(0'u8)
  for shift in countdown(56, 0, 8):
    msg.add(byte((bitLen shr shift) and 0xff'u64))

  var w: array[64, uint32] = default(array[64, uint32])
  var offset = 0
  while offset < msg.len:
    for i in 0 ..< 16:
      let j = offset + i * 4
      w[i] = (uint32(msg[j]) shl 24) or (uint32(msg[j + 1]) shl 16) or
        (uint32(msg[j + 2]) shl 8) or uint32(msg[j + 3])
    for i in 16 ..< 64:
      let s0 = rotr32(w[i - 15], 7) xor rotr32(w[i - 15], 18) xor (w[i - 15] shr 3)
      let s1 = rotr32(w[i - 2], 17) xor rotr32(w[i - 2], 19) xor (w[i - 2] shr 10)
      w[i] = add32(add32(add32(w[i - 16], s0), w[i - 7]), s1)

    var a = h[0]
    var b = h[1]
    var c = h[2]
    var d = h[3]
    var e = h[4]
    var f = h[5]
    var g = h[6]
    var hh = h[7]
    for i in 0 ..< 64:
      let s1 = rotr32(e, 6) xor rotr32(e, 11) xor rotr32(e, 25)
      let ch = (e and f) xor ((not e) and g)
      let temp1 = add32(add32(add32(add32(hh, s1), ch), k[i]), w[i])
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

  for i, value in h:
    result[i * 4] = byte((value shr 24) and 0xff'u32)
    result[i * 4 + 1] = byte((value shr 16) and 0xff'u32)
    result[i * 4 + 2] = byte((value shr 8) and 0xff'u32)
    result[i * 4 + 3] = byte(value and 0xff'u32)

proc bytesToString(bytes: openArray[byte]): string =
  result = newString(bytes.len)
  for i, value in bytes:
    result[i] = char(value)

proc bytesToHex(bytes: openArray[byte]): string =
  const alphabet = "0123456789abcdef"
  result = newString(bytes.len * 2)
  for i, value in bytes:
    result[i * 2] = alphabet[int(value shr 4)]
    result[i * 2 + 1] = alphabet[int(value and 0x0f)]

proc sha256Bytes(data: string): string =
  bytesToString(sha256Digest(data))

proc sha256Hex(data: string): string =
  bytesToHex(sha256Digest(data))

proc hmacSha256Bytes(key, message: string): string =
  const blockSize = 64
  var keyBytes = key
  if keyBytes.len > blockSize:
    keyBytes = sha256Bytes(keyBytes)
  if keyBytes.len < blockSize:
    keyBytes.add(repeat('\0', blockSize - keyBytes.len))
  var outer = newString(blockSize)
  var inner = newString(blockSize)
  for i in 0 ..< blockSize:
    outer[i] = char(ord(keyBytes[i]) xor 0x5c)
    inner[i] = char(ord(keyBytes[i]) xor 0x36)
  sha256Bytes(outer & sha256Bytes(inner & message))

proc hmacSha256Hex(key, message: string): string =
  var digest = hmacSha256Bytes(key, message)
  result = newString(digest.len * 2)
  const alphabet = "0123456789abcdef"
  for i, ch in digest:
    let value = ord(ch) and 0xff
    result[i * 2] = alphabet[value shr 4]
    result[i * 2 + 1] = alphabet[value and 0x0f]

proc validateRelativeLocation(location: string): seq[string] =
  result = @[]
  let normalized = location.strip().replace('\\', '/')
  if normalized.len == 0:
    raise newException(ValueError, "Storage object path is empty.")
  for part in normalized.split('/'):
    if part.len == 0 or part == ".":
      continue
    if part == "..":
      raise newException(ValueError, "Storage object path must not escape provider base path.")
    result.add(part)
  if result.len == 0:
    raise newException(ValueError, "Storage object path is empty.")

proc percentEncode(value: string; slashSafe = false): string =
  const hex = "0123456789ABCDEF"
  result = ""
  for ch in value:
    let code = ord(ch)
    let keep =
      (code >= ord('A') and code <= ord('Z')) or
      (code >= ord('a') and code <= ord('z')) or
      (code >= ord('0') and code <= ord('9')) or
      ch in {'-', '_', '.', '~'} or
      (slashSafe and ch == '/')
    if keep:
      result.add(ch)
    else:
      result.add('%')
      result.add(hex[(code shr 4) and 0x0f])
      result.add(hex[code and 0x0f])

proc trimSlashes(value: string): string =
  value.strip(chars = {'/'})

proc joinS3Path(parts: openArray[string]): string =
  result = ""
  for raw in parts:
    let part = raw.trimSlashes()
    if part.len == 0:
      continue
    if result.len > 0:
      result.add("/")
    result.add(part)

proc s3ObjectKey(provider: Provider; location: string): string =
  let locationKey = validateRelativeLocation(location).join("/")
  let base = provider.basePath.trimSlashes()
  if base.len == 0 or locationKey == base or locationKey.startsWith(base & "/"):
    locationKey
  else:
    base & "/" & locationKey

proc stripS3BasePath(provider: Provider; key: string): string =
  let base = provider.basePath.trimSlashes()
  if base.len > 0 and key == base:
    ""
  elif base.len > 0 and key.startsWith(base & "/"):
    key[(base.len + 1) .. ^1]
  else:
    key

proc hostWithPort(uri: Uri): string =
  result = uri.hostname
  if uri.port.len > 0:
    result.add(":" & uri.port)

proc endpointBaseUrl(endpoint: string): string =
  let parsed = parseUri(endpoint)
  result = parsed.scheme & "://" & hostWithPort(parsed)

proc normalizeEndpoint(endpoint, region: string; useHttps: bool): string =
  var resolved = endpoint.strip()
  if resolved.len == 0:
    let scheme = if useHttps: "https" else: "http"
    let resolvedRegion = if region.strip().len > 0: region.strip() else: "us-east-1"
    resolved = scheme & "://s3." & resolvedRegion & ".amazonaws.com"
  elif not resolved.contains("://"):
    let scheme = if useHttps: "https" else: "http"
    resolved = scheme & "://" & resolved
  resolved.strip(trailing = true, chars = {'/'})

proc mergeBasePath(current, extra: string): string =
  joinS3Path([current, extra])

proc parseS3Url(
    url: string;
    bucket: var string;
    endpoint: var string;
    basePath: var string
) =
  let trimmed = url.strip()
  if trimmed.len == 0:
    return
  let parsed = parseUri(trimmed)
  if parsed.scheme.cmpIgnoreCase("s3") == 0:
    if bucket.len == 0:
      bucket = parsed.hostname
    basePath = mergeBasePath(basePath, parsed.path)
  elif parsed.scheme in ["http", "https"]:
    endpoint = parsed.scheme & "://" & hostWithPort(parsed)
    if parsed.path.trimSlashes().len > 0:
      let pathParts = validateRelativeLocation(parsed.path)
      if bucket.len == 0 and pathParts.len > 0:
        bucket = pathParts[0]
        if pathParts.len > 1:
          basePath = mergeBasePath(basePath, pathParts[1 .. ^1].join("/"))
      else:
        basePath = mergeBasePath(basePath, parsed.path)

proc defaultS3Date(): tuple[amzDate: string, dateStamp: string] =
  let utcNow = getTime().utc()
  (utcNow.format("yyyyMMdd'T'HHmmss'Z'"), utcNow.format("yyyyMMdd"))

proc addHeader(headers: var seq[HeaderPair]; name, value: string) =
  headers.add(HeaderPair(name: name, value: value))

proc toHttpHeaders(headers: openArray[HeaderPair]): HttpHeaders =
  result = newHttpHeaders()
  for header in headers:
    result[header.name] = header.value

proc canonicalHeaderValue(value: string): string =
  value.splitWhitespace().join(" ")

proc canonicalizeHeaders(headers: openArray[HeaderPair]): tuple[canonical: string, signed: string] =
  result = (canonical: "", signed: "")
  var normalized: seq[HeaderPair] = @[]
  for header in headers:
    normalized.add(HeaderPair(
      name: header.name.toLowerAscii(),
      value: canonicalHeaderValue(header.value)
    ))
  normalized.sort(proc(a, b: HeaderPair): int =
    let nameCmp = cmp(a.name, b.name)
    if nameCmp != 0: nameCmp else: cmp(a.value, b.value)
  )
  var signed: seq[string] = @[]
  for header in normalized:
    result.canonical.add(header.name & ":" & header.value & "\n")
    signed.add(header.name)
  result.signed = signed.join(";")

proc canonicalQueryString(params: openArray[(string, string)]): string =
  var encoded: seq[(string, string)] = @[]
  for param in params:
    encoded.add((percentEncode(param[0]), percentEncode(param[1])))
  encoded.sort(proc(a, b: (string, string)): int =
    let keyCmp = cmp(a[0], b[0])
    if keyCmp != 0: keyCmp else: cmp(a[1], b[1])
  )
  var parts: seq[string] = @[]
  for param in encoded:
    parts.add(param[0] & "=" & param[1])
  parts.join("&")

proc signingKey(secret, dateStamp, region: string): string =
  let kDate = hmacSha256Bytes("AWS4" & secret, dateStamp)
  let kRegion = hmacSha256Bytes(kDate, region)
  let kService = hmacSha256Bytes(kRegion, "s3")
  hmacSha256Bytes(kService, "aws4_request")

proc signS3Request(
    provider: Provider;
    httpMethod: string;
    request: var S3Request;
    payloadHash: string;
    amzDate: string;
    dateStamp: string
) =
  if not provider.s3UseSignatures:
    return
  if provider.s3Key.len == 0 or provider.s3Secret.len == 0:
    raise newException(ValueError, "S3 signatures require access key and secret.")
  let canonicalHeaders = canonicalizeHeaders(request.headers)
  let canonicalRequest = httpMethod & "\n" &
    request.canonicalUri & "\n" &
    request.canonicalQuery & "\n" &
    canonicalHeaders.canonical & "\n" &
    canonicalHeaders.signed & "\n" &
    payloadHash
  let region = if provider.s3Region.len > 0: provider.s3Region else: "us-east-1"
  let credentialScope = dateStamp & "/" & region & "/s3/aws4_request"
  let stringToSign = "AWS4-HMAC-SHA256\n" & amzDate & "\n" &
    credentialScope & "\n" & sha256Hex(canonicalRequest)
  let signature = hmacSha256Hex(signingKey(provider.s3Secret, dateStamp, region), stringToSign)
  request.headers.addHeader(
    "Authorization",
    "AWS4-HMAC-SHA256 Credential=" & provider.s3Key & "/" & credentialScope &
      ", SignedHeaders=" & canonicalHeaders.signed &
      ", Signature=" & signature
  )

proc buildS3Request(
    provider: Provider;
    httpMethod, key: string;
    query: openArray[(string, string)] = [];
    body = "";
    extraHeaders: openArray[HeaderPair] = []
): S3Request =
  result = S3Request(url: "", canonicalUri: "", canonicalQuery: "", host: "", headers: @[])
  if provider == nil:
    raise newException(ValueError, "Storage provider is nil.")
  if provider.config.kind != spS3:
    raise newException(ValueError, "Storage provider is not S3.")
  let endpoint = normalizeEndpoint(provider.s3Endpoint, provider.s3Region, provider.s3UseHttps)
  let parsed = parseUri(endpoint)
  var host = hostWithPort(parsed)
  if provider.s3UseVhostRequest:
    host = provider.s3Bucket & "." & host
  let endpointPath = joinS3Path([provider.s3EndpointPath])
  let objectPath =
    if provider.s3UseVhostRequest:
      joinS3Path([endpointPath, key])
    else:
      joinS3Path([endpointPath, provider.s3Bucket, key])
  result.canonicalUri = "/" & percentEncode(objectPath, slashSafe = true)
  result.canonicalQuery = canonicalQueryString(query)
  result.host = host
  result.url = parsed.scheme & "://" & host & result.canonicalUri
  if result.canonicalQuery.len > 0:
    result.url.add("?" & result.canonicalQuery)

  let dates = defaultS3Date()
  let payloadHash =
    if provider.s3UsePayloadSignatures:
      sha256Hex(body)
    else:
      "UNSIGNED-PAYLOAD"
  result.headers = @[]
  result.headers.addHeader("Host", host)
  result.headers.addHeader("x-amz-content-sha256", payloadHash)
  result.headers.addHeader("x-amz-date", dates.amzDate)
  if provider.s3Token.len > 0:
    result.headers.addHeader("x-amz-security-token", provider.s3Token)
  for header in extraHeaders:
    result.headers.add(header)
  provider.signS3Request(httpMethod, result, payloadHash, dates.amzDate, dates.dateStamp)

proc statusCode(resp: Response): int =
  int(resp.code)

proc responseFailed(resp: Response): string =
  $resp.code & ": " & resp.body

proc ensureSuccess(resp: Response; location: string) =
  let code = resp.statusCode()
  if code < 200 or code >= 300:
    raise newException(IOError, "S3 request failed for " & location & ": " & resp.responseFailed())

proc s3Request(provider: Provider; httpMethod: HttpMethod; key: string; body = "";
    query: openArray[(string, string)] = [];
    extraHeaders: openArray[HeaderPair] = []): Response =
  let methodName =
    case httpMethod
    of HttpGet: "GET"
    of HttpHead: "HEAD"
    of HttpPut: "PUT"
    of HttpDelete: "DELETE"
    else: ($httpMethod).toUpperAscii()
  let request = provider.buildS3Request(methodName, key, query, body, extraHeaders)
  var client = newHttpClient()
  client.headers = toHttpHeaders(request.headers)
  {.push warning[Uninit]: off.}
  result = client.request(request.url, httpMethod = httpMethod, body = body)
  {.pop.}

proc childText(node: XmlNode; name: string): string =
  if node == nil:
    return ""
  for child in node.items:
    if child.kind == xnElement and child.tag == name:
      return child.innerText
  ""

proc collectElements(node: XmlNode; name: string; outNodes: var seq[XmlNode]) =
  if node == nil:
    return
  if node.kind == xnElement and node.tag == name:
    outNodes.add(node)
  if node.kind == xnElement:
    for child in node.items:
      collectElements(child, name, outNodes)

proc toAbsPath*(provider: Provider; location: string): string =
  if provider == nil:
    raise newException(ValueError, "Storage provider is nil.")
  var path = provider.basePath
  for part in validateRelativeLocation(location):
    path = path / part
  path

proc stripBasePath(provider: Provider; path: string): string =
  let absBase = normalizedPath(absolutePath(provider.basePath))
  let absPath = normalizedPath(absolutePath(path))
  if absPath == absBase:
    return ""
  var prefix = absBase
  if prefix.len > 0 and prefix[^1] != DirSep:
    prefix.add(DirSep)
  if absPath.startsWith(prefix):
    return absPath[prefix.len .. ^1].replace(DirSep, '/')
  absPath.replace(DirSep, '/')

proc initLocalProvider*(
    name: string,
    basePath: string,
    createIfMissing = true,
    deleteEmptyDirectories = false,
    startupCheck = false
): Provider =
  let trimmedBase = basePath.strip()
  if trimmedBase.len == 0:
    raise newException(ValueError, "Local storage provider base path is required.")
  if createIfMissing:
    createDir(trimmedBase)
  elif not dirExists(trimmedBase):
    raise newException(IOError, "Local storage provider base path does not exist: " & trimmedBase)

  Provider(
    name: if name.strip().len > 0: name.strip() else: "media",
    basePath: trimmedBase,
    config: StorageProviderConfig(
      kind: spLocal,
      name: if name.strip().len > 0: name.strip() else: "media",
      basePath: trimmedBase,
      bucket: "",
      endpoint: "",
      region: "",
      key: "",
      token: "",
      useHttps: false,
      useSignatures: false,
      usePayloadSignatures: false,
      useVhostRequest: false,
      createIfMissing: createIfMissing,
      deleteEmptyDirectories: deleteEmptyDirectories,
      startupCheck: startupCheck,
      multipartThreshold: high(int),
      multipartPartSize: high(int)
    )
  )

proc initS3Provider*(
    name: string,
    url = "",
    bucket = "",
    region = "us-east-1",
    key = "",
    secret = "",
    token = "",
    endpoint = "",
    basePath = "",
    useHttps = true,
    useSignatures = true,
    usePayloadSignatures = true,
    useVhostRequest = false,
    startupCheck = false,
    multipartThreshold = 100 * 1024 * 1024,
    multipartPartSize = 10 * 1024 * 1024
): Provider =
  let label = if name.strip().len > 0: name.strip() else: "s3"
  var resolvedBucket = bucket.strip()
  var resolvedEndpoint = endpoint.strip()
  var resolvedBasePath = basePath.trimSlashes()
  parseS3Url(url, resolvedBucket, resolvedEndpoint, resolvedBasePath)
  if resolvedBucket.len == 0:
    raise newException(ValueError, "S3 storage provider '" & label & "' requires bucket or s3:// URL.")
  let resolvedRegion = if region.strip().len > 0: region.strip() else: "us-east-1"
  let normalized = normalizeEndpoint(resolvedEndpoint, resolvedRegion, useHttps)
  let parsedEndpoint = parseUri(normalized)
  Provider(
    name: label,
    basePath: resolvedBasePath,
    s3Endpoint: endpointBaseUrl(normalized),
    s3EndpointPath: parsedEndpoint.path.trimSlashes(),
    s3Bucket: resolvedBucket,
    s3Region: resolvedRegion,
    s3Key: key,
    s3Secret: secret,
    s3Token: token,
    s3UseHttps: useHttps,
    s3UseSignatures: useSignatures,
    s3UsePayloadSignatures: usePayloadSignatures,
    s3UseVhostRequest: useVhostRequest,
    config: StorageProviderConfig(
      kind: spS3,
      name: label,
      basePath: resolvedBasePath,
      bucket: resolvedBucket,
      endpoint: endpointBaseUrl(normalized),
      region: resolvedRegion,
      key: key,
      token: token,
      useHttps: useHttps,
      useSignatures: useSignatures,
      usePayloadSignatures: usePayloadSignatures,
      useVhostRequest: useVhostRequest,
      createIfMissing: false,
      deleteEmptyDirectories: false,
      startupCheck: startupCheck,
      multipartThreshold: multipartThreshold,
      multipartPartSize: multipartPartSize
    )
  )

proc putOne*(provider: Provider; location: string; body: string): PutResult =
  if provider.config.kind == spS3:
    let key = provider.s3ObjectKey(location)
    let resp = provider.s3Request(HttpPut, key, body = body)
    resp.ensureSuccess(location)
    return PutResult(location: location, size: body.len.int64)
  let path = provider.toAbsPath(location)
  let dir = parentDir(path)
  if dir.len > 0:
    createDir(dir)
  writeFile(path, body)
  PutResult(location: location, size: body.len.int64)

proc get*(provider: Provider; location: string): string =
  if provider.config.kind == spS3:
    let key = provider.s3ObjectKey(location)
    let resp = provider.s3Request(HttpGet, key)
    resp.ensureSuccess(location)
    return resp.body
  readFile(provider.toAbsPath(location))

proc load*(provider: Provider; location: string): string =
  provider.get(location)

proc head*(provider: Provider; location: string): ObjectMeta =
  if provider.config.kind == spS3:
    let key = provider.s3ObjectKey(location)
    let resp = provider.s3Request(HttpHead, key)
    resp.ensureSuccess(location)
    let contentLengths = resp.headers.getOrDefault("content-length")
    let size =
      try:
        if contentLengths.len > 0:
          parseBiggestInt(contentLengths).int64
        else:
          0'i64
      except ValueError:
        0'i64
    return ObjectMeta(location: location, size: size, modifiedUnix: 0)
  let path = provider.toAbsPath(location)
  if not fileExists(path):
    raise newException(IOError, "Storage object not found: " & location)
  ObjectMeta(
    location: location,
    size: getFileSize(path),
    modifiedUnix: getLastModificationTime(path).toUnix()
  )

proc cleanupEmptyParents(provider: Provider; path: string) =
  if not provider.config.deleteEmptyDirectories:
    return
  var dir = parentDir(path)
  let base = normalizedPath(absolutePath(provider.basePath))
  while dir.len > 0 and normalizedPath(absolutePath(dir)).startsWith(base):
    if normalizedPath(absolutePath(dir)) == base:
      break
    var empty = true
    for _ in walkDir(dir):
      empty = false
      break
    if not empty:
      break
    try:
      removeDir(dir)
    except OSError:
      break
    dir = parentDir(dir)

proc deleteOne*(provider: Provider; location: string): bool =
  if provider.config.kind == spS3:
    let key = provider.s3ObjectKey(location)
    let resp = provider.s3Request(HttpDelete, key)
    if resp.statusCode() == 404:
      return false
    resp.ensureSuccess(location)
    return true
  let path = provider.toAbsPath(location)
  if not fileExists(path):
    return false
  removeFile(path)
  provider.cleanupEmptyParents(path)
  true

proc copy*(provider: Provider; src, dst: string; mode = cmOverwrite) =
  if provider.config.kind == spS3:
    if mode == cmCreate:
      let exists =
        try:
          discard provider.head(dst)
          true
        except IOError:
          false
      if exists:
        raise newException(IOError, "Storage destination already exists: " & dst)
    let srcKey = provider.s3ObjectKey(src)
    let dstKey = provider.s3ObjectKey(dst)
    let copySource = "/" & percentEncode(provider.s3Bucket & "/" & srcKey, slashSafe = true)
    let resp = provider.s3Request(
      HttpPut,
      dstKey,
      extraHeaders = [HeaderPair(name: "x-amz-copy-source", value: copySource)]
    )
    resp.ensureSuccess(dst)
    return
  let srcPath = provider.toAbsPath(src)
  let dstPath = provider.toAbsPath(dst)
  if mode == cmCreate and fileExists(dstPath):
    raise newException(IOError, "Storage destination already exists: " & dst)
  let dir = parentDir(dstPath)
  if dir.len > 0:
    createDir(dir)
  copyFile(srcPath, dstPath)

proc rename*(provider: Provider; src, dst: string; mode = cmOverwrite) =
  if provider.config.kind == spS3:
    provider.copy(src, dst, mode)
    discard provider.deleteOne(src)
    return
  let srcPath = provider.toAbsPath(src)
  let dstPath = provider.toAbsPath(dst)
  if mode == cmCreate and fileExists(dstPath):
    raise newException(IOError, "Storage destination already exists: " & dst)
  let dir = parentDir(dstPath)
  if dir.len > 0:
    createDir(dir)
  moveFile(srcPath, dstPath)
  provider.cleanupEmptyParents(srcPath)

proc list*(provider: Provider; prefix = ""): seq[ObjectMeta] =
  result = @[]
  if provider.config.kind == spS3:
    let prefixKey =
      if prefix.strip().len > 0:
        provider.s3ObjectKey(prefix)
      else:
        provider.basePath.trimSlashes()
    let resp = provider.s3Request(
      HttpGet,
      "",
      query = [("list-type", "2"), ("prefix", prefixKey)]
    )
    resp.ensureSuccess(prefix)
    if resp.body.strip().len == 0:
      return @[]
    let xml = parseXml(resp.body)
    var contents: seq[XmlNode] = @[]
    collectElements(xml, "Contents", contents)
    for node in contents:
      let key = node.childText("Key")
      if key.len == 0:
        continue
      let size =
        try:
          parseBiggestInt(node.childText("Size")).int64
        except ValueError:
          0'i64
      result.add(ObjectMeta(
        location: provider.stripS3BasePath(key),
        size: size,
        modifiedUnix: 0
      ))
    result.sort(proc(a, b: ObjectMeta): int = cmp(a.location, b.location))
    return
  let root =
    if prefix.strip().len > 0:
      provider.toAbsPath(prefix)
    else:
      provider.basePath
  if not dirExists(root):
    return @[]
  for path in walkDirRec(root):
    if fileExists(path):
      result.add(ObjectMeta(
        location: provider.stripBasePath(path),
        size: getFileSize(path),
        modifiedUnix: getLastModificationTime(path).toUnix()
      ))
  result.sort(proc(a, b: ObjectMeta): int = cmp(a.location, b.location))

proc ping*(provider: Provider) =
  if provider == nil:
    raise newException(ValueError, "Storage provider is nil.")
  if provider.config.kind == spS3:
    discard provider.list()
    return
  if not dirExists(provider.basePath):
    raise newException(IOError, "Storage provider base path is unavailable: " & provider.basePath)
  discard provider.list()

proc multipartThreshold*(provider: Provider): int =
  defaultMultipartValue(provider.config.multipartThreshold)

proc multipartPartSize*(provider: Provider): int =
  defaultMultipartValue(provider.config.multipartPartSize)

proc chunked*(payload: string; partSize: int): seq[string] =
  result = @[]
  if partSize <= 0:
    raise newException(ValueError, "Chunk part size must be positive.")
  var offset = 0
  while offset < payload.len:
    let nextOffset = min(offset + partSize, payload.len)
    result.add(payload[offset ..< nextOffset])
    offset = nextOffset
