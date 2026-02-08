## client/media_legacy — api module.
##
## Ported from Rust api/client/media_legacy.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/media_legacy.rs"
  RustCrate* = "api"

proc getMediaConfigLegacyRoute*() =
  ## Ported from `get_media_config_legacy_route`.
  discard

proc getMediaConfigLegacyLegacyRoute*() =
  ## Ported from `get_media_config_legacy_legacy_route`.
  discard

proc getMediaPreviewLegacyRoute*() =
  ## Ported from `get_media_preview_legacy_route`.
  discard

proc getMediaPreviewLegacyLegacyRoute*() =
  ## Ported from `get_media_preview_legacy_legacy_route`.
  discard

proc createContentLegacyRoute*() =
  ## Ported from `create_content_legacy_route`.
  discard

proc getContentLegacyRoute*() =
  ## Ported from `get_content_legacy_route`.
  discard

proc getContentLegacyLegacyRoute*() =
  ## Ported from `get_content_legacy_legacy_route`.
  discard

proc getContentAsFilenameLegacyRoute*() =
  ## Ported from `get_content_as_filename_legacy_route`.
  discard

proc getContentAsFilenameLegacyLegacyRoute*() =
  ## Ported from `get_content_as_filename_legacy_legacy_route`.
  discard

proc getContentThumbnailLegacyRoute*() =
  ## Ported from `get_content_thumbnail_legacy_route`.
  discard

proc getContentThumbnailLegacyLegacyRoute*() =
  ## Ported from `get_content_thumbnail_legacy_legacy_route`.
  discard
