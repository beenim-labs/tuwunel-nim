## client/media — api module.
##
## Ported from Rust api/client/media.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/media.rs"
  RustCrate* = "api"

proc getMediaConfigRoute*() =
  ## Ported from `get_media_config_route`.
  discard

proc createContentRoute*() =
  ## Ported from `create_content_route`.
  discard

proc getContentThumbnailRoute*() =
  ## Ported from `get_content_thumbnail_route`.
  discard

proc getContentRoute*() =
  ## Ported from `get_content_route`.
  discard

proc getContentAsFilenameRoute*() =
  ## Ported from `get_content_as_filename_route`.
  discard

proc getMediaPreviewRoute*() =
  ## Ported from `get_media_preview_route`.
  discard

proc fetchThumbnail*(services: Services; mxc: Mxc<'_>; user: string; timeoutMs: Duration; dim: Dim): FileMeta =
  ## Ported from `fetch_thumbnail`.
  discard

proc fetchFile*(services: Services; mxc: Mxc<'_>; user: string; timeoutMs: Duration; filename: Option[string]): FileMeta =
  ## Ported from `fetch_file`.
  discard

proc fetchThumbnailMeta*(services: Services; mxc: Mxc<'_>; user: string; timeoutMs: Duration; dim: Dim): FileMeta =
  ## Ported from `fetch_thumbnail_meta`.
  discard

proc fetchFileMeta*(services: Services; mxc: Mxc<'_>; user: string; timeoutMs: Duration): FileMeta =
  ## Ported from `fetch_file_meta`.
  discard
