const
  RustPath* = "api/client/media_legacy.rs"
  RustCrate* = "api"

import std/json
import ./media as client_media

proc legacyMediaConfigResponse*(maxUploadSize: int): JsonNode =
  client_media.mediaConfigResponse(maxUploadSize)

proc legacyPreviewResponse*(url: string): JsonNode =
  client_media.previewResponse(url)
