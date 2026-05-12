import std/[options, strutils, uri]

const
  RustPath* = "service/media/preview.rs"
  RustCrate* = "service"

type
  UrlPreviewData* = object
    title*: Option[string]
    description*: Option[string]
    image*: Option[string]
    imageSize*: Option[uint]
    imageWidth*: Option[uint32]
    imageHeight*: Option[uint32]
    video*: Option[string]
    videoSize*: Option[uint]
    videoWidth*: Option[uint32]
    videoHeight*: Option[uint32]
    audio*: Option[string]
    audioSize*: Option[uint]
    ogType*: Option[string]
    ogUrl*: Option[string]

  UrlPreviewPolicy* = object
    domainContainsAllowlist*: seq[string]
    domainExplicitAllowlist*: seq[string]
    domainExplicitDenylist*: seq[string]
    urlContainsAllowlist*: seq[string]
    checkRootDomain*: bool

proc initUrlPreviewData*(): UrlPreviewData =
  UrlPreviewData()

proc initUrlPreviewPolicy*(): UrlPreviewPolicy =
  UrlPreviewPolicy(
    domainContainsAllowlist: @[],
    domainExplicitAllowlist: @[],
    domainExplicitDenylist: @[],
    urlContainsAllowlist: @[],
    checkRootDomain: false,
  )

proc someNonEmpty(value: string): Option[string] =
  if value.len == 0: none(string) else: some(value)

proc parseUrlHost(rawUrl: string): tuple[ok: bool, scheme: string, host: string] =
  result = (false, "", "")
  try:
    let parsed = parseUri(rawUrl)
    result.scheme = parsed.scheme
    result.host = parsed.hostname
    result.ok = result.scheme.len > 0 and result.host.len > 0
  except CatchableError:
    result = (false, "", "")

proc rootDomain(host: string): string =
  let idx = host.find('.')
  if idx < 0 or idx + 1 >= host.len:
    ""
  else:
    host[idx + 1 .. ^1]

proc urlPreviewAllowed*(policy: UrlPreviewPolicy; rawUrl: string): bool =
  let parsed = parseUrlHost(rawUrl)
  if not parsed.ok:
    return false
  if parsed.scheme.toLowerAscii() notin ["http", "https"]:
    return false

  let host = parsed.host
  if "*" in policy.domainContainsAllowlist or
      "*" in policy.domainExplicitAllowlist or
      "*" in policy.urlContainsAllowlist:
    return true

  if host in policy.domainExplicitDenylist:
    return false
  if host in policy.domainExplicitAllowlist:
    return true
  for domain in policy.domainContainsAllowlist:
    if domain.len > 0 and domain.contains(host):
      return true
  for fragment in policy.urlContainsAllowlist:
    if fragment.len > 0 and rawUrl.contains(fragment):
      return true

  if policy.checkRootDomain:
    let root = rootDomain(host)
    if root.len == 0:
      return false
    if root in policy.domainExplicitDenylist:
      return false
    if root in policy.domainExplicitAllowlist:
      return true
    for domain in policy.domainContainsAllowlist:
      if domain.len > 0 and domain.contains(root):
        return true

  false

proc textField(value: Option[string]): string =
  if value.isSome: value.get() else: ""

proc uintField(value: Option[uint]): string =
  if value.isSome: $value.get() else: "0"

proc uint32Field(value: Option[uint32]): string =
  if value.isSome: $value.get() else: "0"

proc encodeUrlPreview*(data: UrlPreviewData; timestampSecs: uint64): string =
  let sep = $char(0xFF)
  @[
    $timestampSecs,
    textField(data.title),
    textField(data.description),
    textField(data.image),
    uintField(data.imageSize),
    uint32Field(data.imageWidth),
    uint32Field(data.imageHeight),
    textField(data.video),
    uintField(data.videoSize),
    uint32Field(data.videoWidth),
    uint32Field(data.videoHeight),
    textField(data.audio),
    uintField(data.audioSize),
    textField(data.ogType),
    textField(data.ogUrl),
  ].join(sep)

proc parseUIntField(value: string): Option[uint] =
  try:
    let parsed = parseUInt(value)
    if parsed == 0'u: none(uint) else: some(parsed)
  except ValueError:
    none(uint)

proc parseUInt32Field(value: string): Option[uint32] =
  try:
    let parsed = uint32(parseUInt(value))
    if parsed == 0'u32: none(uint32) else: some(parsed)
  except ValueError:
    none(uint32)

proc decodeUrlPreview*(payload: string): UrlPreviewData =
  let parts = payload.split(char(0xFF))
  proc part(idx: int): string =
    if idx >= 0 and idx < parts.len: parts[idx] else: ""

  UrlPreviewData(
    title: someNonEmpty(part(1)),
    description: someNonEmpty(part(2)),
    image: someNonEmpty(part(3)),
    imageSize: parseUIntField(part(4)),
    imageWidth: parseUInt32Field(part(5)),
    imageHeight: parseUInt32Field(part(6)),
    video: someNonEmpty(part(7)),
    videoSize: parseUIntField(part(8)),
    videoWidth: parseUInt32Field(part(9)),
    videoHeight: parseUInt32Field(part(10)),
    audio: someNonEmpty(part(11)),
    audioSize: parseUIntField(part(12)),
    ogType: someNonEmpty(part(13)),
    ogUrl: someNonEmpty(part(14)),
  )
