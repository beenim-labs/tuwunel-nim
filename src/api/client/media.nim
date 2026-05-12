const
  RustPath* = "api/client/media.rs"
  RustCrate* = "api"
  CacheControlImmutable* = "public, max-age=31536000, immutable"

import std/[json, strutils]

type
  MediaPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc mediaConfigResponse*(maxUploadSize: int): JsonNode =
  %*{"m.upload.size": maxUploadSize}

proc contentUri*(serverName, mediaId: string): string =
  "mxc://" & serverName & "/" & mediaId

proc uploadResponse*(serverName, mediaId: string; blurhash = ""): JsonNode =
  result = %*{"content_uri": contentUri(serverName, mediaId)}
  if blurhash.len > 0:
    result["blurhash"] = %blurhash

proc asyncUploadResponse*(): JsonNode =
  newJObject()

proc previewPolicy*(url: string): MediaPolicyResult =
  let trimmed = url.strip()
  if trimmed.len == 0:
    return (false, "M_INVALID_PARAM", "Missing url query parameter.")
  if not (trimmed.startsWith("http://") or trimmed.startsWith("https://")):
    return (false, "M_INVALID_PARAM", "Invalid preview URL.")
  (true, "", "")

proc previewResponse*(url: string): JsonNode =
  %*{
    "og:url": url,
    "og:title": url,
  }

proc mediaNotFound*(): MediaPolicyResult =
  (false, "M_NOT_FOUND", "Media not found.")
