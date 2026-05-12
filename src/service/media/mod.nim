import std/[options, tables]

import service/media/[blurhash, data, migrations, preview, remote, tests, thumbnail]

export blurhash, data, migrations, preview, remote, tests, thumbnail

const
  RustPath* = "service/media/mod.rs"
  RustCrate* = "service"
  MxcLength* = 32
  CacheControlImmutable* = "private,max-age=31536000,immutable"
  CorpCrossOrigin* = "cross-origin"

type
  Media* = object
    content*: seq[byte]
    contentType*: Option[string]
    contentDisposition*: Option[string]

  MediaResult* = tuple[ok: bool, errcode: string, message: string, retryAfterMs: uint64]

  RateLimitState = object
    lastMs: uint64
    tokens: float

  MediaService* = object
    db*: MediaData
    files*: Table[string, seq[byte]]
    maxPendingMediaUploads*: int
    mediaRcCreatePerSecond*: float
    mediaRcCreateBurstCount*: float
    rateLimits: Table[string, RateLimitState]

proc initMediaService*(
  maxPendingMediaUploads = 100;
  mediaRcCreatePerSecond = 0.0;
  mediaRcCreateBurstCount = 0.0;
): MediaService =
  MediaService(
    db: initMediaData(),
    files: initTable[string, seq[byte]](),
    maxPendingMediaUploads: maxPendingMediaUploads,
    mediaRcCreatePerSecond: mediaRcCreatePerSecond,
    mediaRcCreateBurstCount: mediaRcCreateBurstCount,
    rateLimits: initTable[string, RateLimitState](),
  )

proc okResult(): MediaResult =
  (true, "", "", 0'u64)

proc mediaError(errcode, message: string; retryAfterMs = 0'u64): MediaResult =
  (false, errcode, message, retryAfterMs)

proc checkPendingRateLimit(service: var MediaService; userId: string; nowMs: uint64): MediaResult =
  let rate = service.mediaRcCreatePerSecond
  let burst = service.mediaRcCreateBurstCount
  if rate <= 0.0 or burst <= 0.0:
    return okResult()

  var state = service.rateLimits.getOrDefault(
    userId,
    RateLimitState(lastMs: nowMs, tokens: burst),
  )
  let elapsedSecs =
    if nowMs > state.lastMs: float(nowMs - state.lastMs) / 1000.0 else: 0.0
  state.tokens = min(burst, state.tokens + elapsedSecs * rate)
  state.lastMs = nowMs
  if state.tokens >= 1.0:
    state.tokens -= 1.0
    service.rateLimits[userId] = state
    return okResult()

  service.rateLimits[userId] = state
  mediaError("M_LIMIT_EXCEEDED", "Too many pending media creation requests.")

proc createPending*(
  service: var MediaService;
  mxc, userId: string;
  expiresAt: uint64;
  nowMs = 0'u64;
): MediaResult =
  let limited = service.checkPendingRateLimit(userId, nowMs)
  if not limited.ok:
    return limited

  let pending = countPendingMxcForUser(service.db, userId)
  if service.maxPendingMediaUploads >= 0 and pending.count >= service.maxPendingMediaUploads:
    let retryAfter =
      if pending.earliestExpiration > nowMs: pending.earliestExpiration - nowMs else: 0'u64
    return mediaError(
      "M_LIMIT_EXCEEDED",
      "Maximum number of pending media uploads reached.",
      retryAfter,
    )

  insertPendingMxc(service.db, mxc, userId, expiresAt)
  okResult()

proc create*(
  service: var MediaService;
  mxc: string;
  file: openArray[byte];
  userId: Option[string] = none(string);
  contentDisposition: Option[string] = none(string);
  contentType: Option[string] = none(string);
): MediaResult =
  let key = createFileMetadata(
    service.db,
    mxc,
    userId,
    defaultDim(),
    contentDisposition,
    contentType,
  )
  service.files[key] = @file
  okResult()

proc uploadPending*(
  service: var MediaService;
  mxc, userId: string;
  file: openArray[byte];
  contentDisposition: Option[string] = none(string);
  contentType: Option[string] = none(string);
  nowMs = 0'u64;
): MediaResult =
  let pending = searchPendingMxc(service.db, mxc)
  if not pending.ok:
    if fileMetadataExists(service.db, mxc, defaultDim()):
      return mediaError("M_CANNOT_OVERWRITE_MEDIA", "Media ID already has content")
    return mediaError("M_NOT_FOUND", "Media not found")

  if pending.userId != userId:
    return mediaError("M_FORBIDDEN", "You did not create this media ID")
  if pending.expiresAt < nowMs:
    return mediaError("M_NOT_FOUND", "Pending media ID expired")

  let created = service.create(mxc, file, some(userId), contentDisposition, contentType)
  if created.ok:
    removePendingMxc(service.db, mxc)
  created

proc uploadThumbnail*(
  service: var MediaService;
  mxc: string;
  dim: Dim;
  file: openArray[byte];
  contentDisposition: Option[string] = none(string);
  contentType: Option[string] = none(string);
): MediaResult =
  let key = createFileMetadata(service.db, mxc, none(string), dim, contentDisposition, contentType)
  service.files[key] = @file
  okResult()

proc getStored*(
  service: MediaService;
  mxc: string;
): tuple[ok: bool, media: Media, message: string] =
  let found = searchFileMetadata(service.db, mxc, defaultDim())
  if not found.ok:
    return (false, Media(), "Media not found.")
  if found.metadata.key notin service.files:
    return (false, Media(), "Media not found.")
  (true, Media(
    content: service.files[found.metadata.key],
    contentType: found.metadata.contentType,
    contentDisposition: found.metadata.contentDisposition,
  ), "")

proc get*(
  service: MediaService;
  mxc: string;
  timeoutMs: Option[uint64] = none(uint64);
): tuple[ok: bool, media: Media, errcode: string, message: string] =
  let stored = service.getStored(mxc)
  if stored.ok:
    return (true, stored.media, "", "")
  if timeoutMs.isNone or not searchPendingMxc(service.db, mxc).ok:
    return (false, Media(), "M_NOT_FOUND", "Media not found.")
  (false, Media(), "M_NOT_YET_UPLOADED", "Media has not been uploaded yet")

proc getThumbnail*(
  service: MediaService;
  mxc: string;
  dim: Dim;
): tuple[ok: bool, media: Media, errcode: string, message: string] =
  let normalized = dim.normalized()
  let thumb = searchFileMetadata(service.db, mxc, normalized)
  if thumb.ok and thumb.metadata.key in service.files:
    return (true, Media(
      content: service.files[thumb.metadata.key],
      contentType: thumb.metadata.contentType,
      contentDisposition: thumb.metadata.contentDisposition,
    ), "", "")

  let original = service.getStored(mxc)
  if original.ok:
    return (true, original.media, "", "")

  (false, Media(), "M_NOT_FOUND", "Media thumbnail not found.")

proc delete*(service: var MediaService; mxc: string): MediaResult =
  let keys = searchMxcMetadataPrefix(service.db, mxc)
  if keys.len == 0:
    return mediaError("M_NOT_FOUND", "Failed to find any media keys for MXC.")
  for key in keys:
    service.files.del(key)
  deleteFileMxc(service.db, mxc)
  okResult()

proc deleteFromUser*(service: var MediaService; userId: string): int =
  let mxcs = getAllUserMxcs(service.db, userId)
  for mxc in mxcs:
    if service.delete(mxc).ok:
      inc result

proc getAllMxcs*(service: MediaService): seq[string] =
  getAllMxcs(service.db)

proc getAllMediaKeys*(service: MediaService): seq[string] =
  getAllMediaKeys(service.db)

proc setUrlPreview*(
  service: var MediaService;
  url: string;
  preview: UrlPreviewData;
  timestampSecs: uint64;
) =
  setUrlPreview(service.db, url, preview, timestampSecs)

proc getUrlPreview*(
  service: MediaService;
  url: string;
): tuple[ok: bool, preview: UrlPreviewData] =
  getUrlPreview(service.db, url)

proc removeUrlPreview*(service: var MediaService; url: string) =
  removeUrlPreview(service.db, url)
