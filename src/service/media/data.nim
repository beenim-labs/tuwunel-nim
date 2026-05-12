import std/[algorithm, options, strutils, tables]

import service/media/preview
import service/media/thumbnail

const
  RustPath* = "service/media/data.rs"
  RustCrate* = "service"
  MediaKeySeparator* = char(0xFF)

type
  Metadata* = object
    contentDisposition*: Option[string]
    contentType*: Option[string]
    key*: string
    mxc*: string
    dim*: Dim
    userId*: Option[string]

  PendingMxc* = object
    userId*: string
    expiresAt*: uint64

  MediaData* = object
    mediaidFile*: OrderedTable[string, Metadata]
    mediaidPending*: Table[string, PendingMxc]
    mediaidUser*: Table[string, string]
    urlPreviews*: Table[string, string]

proc initMediaData*(): MediaData =
  MediaData(
    mediaidFile: initOrderedTable[string, Metadata](),
    mediaidPending: initTable[string, PendingMxc](),
    mediaidUser: initTable[string, string](),
    urlPreviews: initTable[string, string](),
  )

proc mediaKey*(
  mxc: string;
  dim: Dim;
  contentDisposition: Option[string] = none(string);
  contentType: Option[string] = none(string);
): string =
  let sep = $MediaKeySeparator
  mxc & sep &
    $dim.width & "," & $dim.height & sep &
    (if contentDisposition.isSome: contentDisposition.get() else: "") & sep &
    (if contentType.isSome: contentType.get() else: "")

proc createFileMetadata*(
  data: var MediaData;
  mxc: string;
  userId: Option[string];
  dim: Dim;
  contentDisposition: Option[string] = none(string);
  contentType: Option[string] = none(string);
): string =
  result = mediaKey(mxc, dim, contentDisposition, contentType)
  data.mediaidFile[result] = Metadata(
    contentDisposition: contentDisposition,
    contentType: contentType,
    key: result,
    mxc: mxc,
    dim: dim,
    userId: userId,
  )
  if userId.isSome:
    data.mediaidUser[mxc & $MediaKeySeparator & userId.get()] = userId.get()

proc insertPendingMxc*(data: var MediaData; mxc, userId: string; expiresAt: uint64) =
  data.mediaidPending[mxc] = PendingMxc(userId: userId, expiresAt: expiresAt)

proc removePendingMxc*(data: var MediaData; mxc: string) =
  data.mediaidPending.del(mxc)

proc searchPendingMxc*(
  data: MediaData;
  mxc: string;
): tuple[ok: bool, userId: string, expiresAt: uint64] =
  if mxc notin data.mediaidPending:
    return (false, "", 0'u64)
  let pending = data.mediaidPending[mxc]
  (true, pending.userId, pending.expiresAt)

proc countPendingMxcForUser*(
  data: MediaData;
  userId: string;
): tuple[count: int, earliestExpiration: uint64] =
  result = (0, high(uint64))
  for pending in data.mediaidPending.values:
    if pending.userId == userId:
      inc result.count
      result.earliestExpiration = min(result.earliestExpiration, pending.expiresAt)
  if result.count == 0:
    result.earliestExpiration = 0'u64

proc deleteFileMxc*(data: var MediaData; mxc: string) =
  var fileKeys: seq[string] = @[]
  for key, metadata in data.mediaidFile:
    if metadata.mxc == mxc:
      fileKeys.add(key)
  for key in fileKeys:
    data.mediaidFile.del(key)

  var userKeys: seq[string] = @[]
  for key in data.mediaidUser.keys:
    if key.startsWith(mxc & $MediaKeySeparator):
      userKeys.add(key)
  for key in userKeys:
    data.mediaidUser.del(key)

proc searchMxcMetadataPrefix*(data: MediaData; mxc: string): seq[string] =
  result = @[]
  for key, metadata in data.mediaidFile:
    if metadata.mxc == mxc:
      result.add(key)

proc fileMetadataExists*(data: MediaData; mxc: string; dim: Dim): bool =
  for metadata in data.mediaidFile.values:
    if metadata.mxc == mxc and metadata.dim == dim:
      return true
  false

proc searchFileMetadata*(
  data: MediaData;
  mxc: string;
  dim: Dim;
): tuple[ok: bool, metadata: Metadata] =
  for metadata in data.mediaidFile.values:
    if metadata.mxc == mxc and metadata.dim == dim:
      return (true, metadata)
  (false, Metadata())

proc getAllUserMxcs*(data: MediaData; userId: string): seq[string] =
  result = @[]
  var seen = initTable[string, bool]()
  for key, value in data.mediaidUser:
    if value != userId:
      continue
    let sep = key.find(MediaKeySeparator)
    if sep <= 0:
      continue
    let mxc = key[0 ..< sep]
    if mxc notin seen:
      seen[mxc] = true
      result.add(mxc)
  result.sort(system.cmp[string])

proc getAllMediaKeys*(data: MediaData): seq[string] =
  result = @[]
  for key in data.mediaidFile.keys:
    result.add(key)

proc getAllMxcs*(data: MediaData): seq[string] =
  result = @[]
  var seen = initTable[string, bool]()
  for metadata in data.mediaidFile.values:
    if metadata.mxc.len > 0 and metadata.mxc notin seen:
      seen[metadata.mxc] = true
      result.add(metadata.mxc)
  result.sort(system.cmp[string])

proc removeUrlPreview*(data: var MediaData; url: string) =
  data.urlPreviews.del(url)

proc setUrlPreview*(
  data: var MediaData;
  url: string;
  preview: UrlPreviewData;
  timestampSecs: uint64;
) =
  data.urlPreviews[url] = encodeUrlPreview(preview, timestampSecs)

proc getUrlPreview*(data: MediaData; url: string): tuple[ok: bool, preview: UrlPreviewData] =
  if url notin data.urlPreviews:
    return (false, UrlPreviewData())
  (true, decodeUrlPreview(data.urlPreviews[url]))
