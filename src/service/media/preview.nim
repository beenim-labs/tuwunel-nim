## media/preview — service module.
##
## Ported from Rust service/media/preview.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/preview.rs"
  RustCrate* = "service"

type
  UrlPreviewData* = ref object
    title*: Option[string]
    description*: Option[string]
    image*: Option[string]
    imageSize*: Option[int]
    imageWidth*: Option[uint32]
    imageHeight*: Option[uint32]

proc removeUrlPreview*(self: UrlPreviewData; url: string) =
  ## Ported from `remove_url_preview`.
  discard

proc setUrlPreview*(self: UrlPreviewData; url: string; data: UrlPreviewData) =
  ## Ported from `set_url_preview`.
  discard

proc getUrlPreview*(self: UrlPreviewData; url: Url): UrlPreviewData =
  ## Ported from `get_url_preview`.
  discard

proc requestUrlPreview*(self: UrlPreviewData; url: Url): UrlPreviewData =
  ## Ported from `request_url_preview`.
  discard

proc downloadImage*(self: UrlPreviewData; url: string): UrlPreviewData =
  ## Ported from `download_image`.
  discard

proc downloadImage*(self: UrlPreviewData; Url: string): UrlPreviewData =
  ## Ported from `download_image`.
  discard

proc downloadHtml*(self: UrlPreviewData; url: string): UrlPreviewData =
  ## Ported from `download_html`.
  discard

proc downloadHtml*(self: UrlPreviewData; Url: string): UrlPreviewData =
  ## Ported from `download_html`.
  discard

proc urlPreviewAllowed*(self: UrlPreviewData; url: Url): bool =
  ## Ported from `url_preview_allowed`.
  false
