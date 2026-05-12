import std/[options, unittest]

import "service/media/mod" as media_service

proc bytes(value: string): seq[byte] =
  for ch in value:
    result.add(byte(ord(ch)))

suite "Service media parity":
  test "thumbnail dimensions normalize and scale like Rust buckets":
    check media_service.initDim(16'u32, 16'u32).normalized() ==
      media_service.initDim(32'u32, 32'u32, media_service.tmCrop)
    check media_service.initDim(80'u32, 90'u32).normalized() ==
      media_service.initDim(96'u32, 96'u32, media_service.tmCrop)
    check media_service.initDim(300'u32, 200'u32).normalized() ==
      media_service.initDim(320'u32, 240'u32, media_service.tmScale)
    check media_service.initDim(900'u32, 700'u32).normalized() ==
      media_service.defaultDim()

    let scaled = media_service.initDim(320'u32, 240'u32).scaled(
      media_service.initDim(1600'u32, 900'u32)
    )
    check scaled.ok
    check scaled.dim == media_service.initDim(426'u32, 240'u32, media_service.tmScale)

  test "pending upload enforces owner expiry max count and overwrite policy":
    var service = media_service.initMediaService(maxPendingMediaUploads = 1)
    let first = media_service.createPending(
      service,
      "mxc://localhost/pending1",
      "@alice:localhost",
      expiresAt = 10_000'u64,
      nowMs = 1_000'u64,
    )
    check first.ok

    let tooMany = media_service.createPending(
      service,
      "mxc://localhost/pending2",
      "@alice:localhost",
      expiresAt = 11_000'u64,
      nowMs = 2_000'u64,
    )
    check not tooMany.ok
    check tooMany.errcode == "M_LIMIT_EXCEEDED"
    check tooMany.retryAfterMs == 8_000'u64

    let wrongUser = media_service.uploadPending(
      service,
      "mxc://localhost/pending1",
      "@bob:localhost",
      bytes("body"),
      nowMs = 2_000'u64,
    )
    check not wrongUser.ok
    check wrongUser.errcode == "M_FORBIDDEN"

    let uploaded = media_service.uploadPending(
      service,
      "mxc://localhost/pending1",
      "@alice:localhost",
      bytes("body"),
      contentType = some("text/plain"),
      nowMs = 2_000'u64,
    )
    check uploaded.ok
    check not media_service.searchPendingMxc(service.db, "mxc://localhost/pending1").ok

    let stored = media_service.get(service, "mxc://localhost/pending1")
    check stored.ok
    check stored.media.content == bytes("body")
    check stored.media.contentType.get() == "text/plain"

    let overwrite = media_service.uploadPending(
      service,
      "mxc://localhost/pending1",
      "@alice:localhost",
      bytes("new"),
    )
    check not overwrite.ok
    check overwrite.errcode == "M_CANNOT_OVERWRITE_MEDIA"

  test "media create get thumbnail fallback and delete follow local storage metadata":
    var service = media_service.initMediaService()
    check media_service.create(
      service,
      "mxc://localhost/media1",
      bytes("original"),
      userId = some("@alice:localhost"),
      contentDisposition = some("inline; filename=one.txt"),
      contentType = some("text/plain"),
    ).ok

    check media_service.getAllMxcs(service) == @["mxc://localhost/media1"]
    check media_service.getAllUserMxcs(service.db, "@alice:localhost") == @["mxc://localhost/media1"]

    let fallbackThumb = media_service.getThumbnail(
      service,
      "mxc://localhost/media1",
      media_service.initDim(32'u32, 32'u32),
    )
    check fallbackThumb.ok
    check fallbackThumb.media.content == bytes("original")

    check media_service.uploadThumbnail(
      service,
      "mxc://localhost/media1",
      media_service.initDim(32'u32, 32'u32).normalized(),
      bytes("thumb"),
      contentType = some("image/png"),
    ).ok
    let thumbnail = media_service.getThumbnail(
      service,
      "mxc://localhost/media1",
      media_service.initDim(32'u32, 32'u32),
    )
    check thumbnail.ok
    check thumbnail.media.content == bytes("thumb")
    check thumbnail.media.contentType.get() == "image/png"

    check media_service.deleteFromUser(service, "@alice:localhost") == 1
    check not media_service.get(service, "mxc://localhost/media1").ok

  test "url preview cache serialization and allow policy mirror Rust branches":
    var service = media_service.initMediaService()
    var preview = media_service.initUrlPreviewData()
    preview.title = some("Example")
    preview.description = some("Description")
    preview.image = some("mxc://localhost/img")
    preview.imageSize = some(42'u)
    preview.imageWidth = some(320'u32)
    preview.imageHeight = some(240'u32)
    preview.ogType = some("article")
    preview.ogUrl = some("https://example.com/post")

    media_service.setUrlPreview(service, "https://example.com/post", preview, 1_234'u64)
    let cached = media_service.getUrlPreview(service, "https://example.com/post")
    check cached.ok
    check cached.preview.title.get() == "Example"
    check cached.preview.imageSize.get() == 42'u
    check cached.preview.imageWidth.get() == 320'u32
    media_service.removeUrlPreview(service, "https://example.com/post")
    check not media_service.getUrlPreview(service, "https://example.com/post").ok

    var policy = media_service.initUrlPreviewPolicy()
    policy.domainExplicitDenylist = @["blocked.example"]
    policy.domainExplicitAllowlist = @["example.com"]
    policy.urlContainsAllowlist = @["/allowed/"]
    check policy.urlPreviewAllowed("https://example.com/post")
    check not policy.urlPreviewAllowed("https://blocked.example/post")
    check policy.urlPreviewAllowed("https://elsewhere.test/allowed/post")
    check not policy.urlPreviewAllowed("ftp://example.com/post")

  test "remote media policy and disabled blurhash expose native decisions":
    var policy = media_service.initRemoteMediaPolicy()
    policy.blockedHosts = @["evil"]
    policy.forbiddenServers = @["blocked.example"]
    policy.requestLegacyMedia = true
    policy.freezeLegacyMedia = true

    check not policy.fetchAuthorized("media.evil.example")
    check not policy.fetchAuthorized("blocked.example")
    check policy.fetchAuthorized("matrix.example")
    check policy.shouldTryLegacyFallback("M_NOT_FOUND", 404)
    check policy.shouldTryLegacyFallback("", 502)
    check not policy.legacyFetchAllowed()

    let blurhash = media_service.createBlurhash(
      media_service.initBlurhashConfig(),
      bytes("not-image"),
    )
    check blurhash.ok
    check blurhash.blurhash.isNone

  test "media migration inventory is fully applied":
    check media_service.allMediaMigrationsApplied(media_service.defaultMediaMigrations())
    check media_service.mediaServiceTestSlice().contains("pending-upload")
