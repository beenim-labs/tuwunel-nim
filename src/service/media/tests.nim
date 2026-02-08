## media/tests — service module.
##
## Ported from Rust service/media/tests.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/tests.rs"
  RustCrate* = "service"

proc longFileNamesWorks*() =
  ## Ported from `long_file_names_works`.
  discard

proc createFileMetadata*(SenderUser: Option[string]; mxc: string; width: uint32; height: uint32; contentDisposition: Option[string]; contentType: Option[string]): seq[u8] =
  ## Ported from `create_file_metadata`.
  @[]

proc deleteFileMxc*(Mxc: string) =
  ## Ported from `delete_file_mxc`.
  discard

proc searchMxcMetadataPrefix*(Mxc: string): seq[Vec<u8]> =
  ## Ported from `search_mxc_metadata_prefix`.
  @[]

proc getAllMediaKeys*(): seq[Vec<u8]> =
  ## Ported from `get_all_media_keys`.
  @[]

proc searchFileMetadata*(Mxc: string; Width: uint32; Height: uint32): (Option[string, Option<string], seq[u8])> =
  ## Ported from `search_file_metadata`.
  discard

proc removeUrlPreview*(Url: string) =
  ## Ported from `remove_url_preview`.
  discard

proc setUrlPreview*(Url: string; Data: UrlPreviewData; Timestamp: std::time::Duration) =
  ## Ported from `set_url_preview`.
  discard

proc getUrlPreview*(Url: string): Option[UrlPreviewData] =
  ## Ported from `get_url_preview`.
  none(UrlPreviewData)
