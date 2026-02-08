## media/data — service module.
##
## Ported from Rust service/media/data.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/data.rs"
  RustCrate* = "service"

proc createFileMetadata*(mxc: Mxc<'_>; user: Option[string]; dim: Dim; contentDisposition: Option[ContentDisposition]; contentType: Option[string]): seq[u8] =
  ## Ported from `create_file_metadata`.
  @[]

proc deleteFileMxc*(mxc: Mxc<'_>) =
  ## Ported from `delete_file_mxc`.
  discard

proc searchMxcMetadataPrefix*(mxc: Mxc<'_>): seq[Vec<u8]> =
  ## Ported from `search_mxc_metadata_prefix`.
  @[]

proc searchFileMetadata*(mxc: Mxc<'_>; dim: Dim): Metadata =
  ## Ported from `search_file_metadata`.
  discard

proc getAllUserMxcs*(userId: string): seq[string] =
  ## Ported from `get_all_user_mxcs`.
  @[]

proc getAllMediaKeys*(): seq[Vec<u8]> =
  ## Ported from `get_all_media_keys`.
  @[]

proc removeUrlPreview*(url: string) =
  ## Ported from `remove_url_preview`.
  discard

proc setUrlPreview*(url: string; data: UrlPreviewData; timestamp: Duration) =
  ## Ported from `set_url_preview`.
  discard

proc getUrlPreview*(url: string): UrlPreviewData =
  ## Ported from `get_url_preview`.
  discard
