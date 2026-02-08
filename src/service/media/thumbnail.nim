## media/thumbnail — service module.
##
## Ported from Rust service/media/thumbnail.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/thumbnail.rs"
  RustCrate* = "service"

type
  Dim* = ref object
    width*: uint32
    height*: uint32
    method*: Method

proc uploadThumbnail*(self: Dim; mxc: Mxc<'_>; user: Option[string]; contentDisposition: Option[ContentDisposition]; contentType: Option[string]; dim: Dim; file: [u8]) =
  ## Ported from `upload_thumbnail`.
  discard

proc getThumbnail*(self: Dim; mxc: Mxc<'_>; dim: Dim): Option[FileMeta] =
  ## Ported from `get_thumbnail`.
  none(FileMeta)

proc getThumbnailSaved*(self: Dim; data: Metadata): Option[FileMeta] =
  ## Ported from `get_thumbnail_saved`.
  none(FileMeta)

proc getThumbnailGenerate*(self: Dim; mxc: Mxc<'_>; dim: Dim; data: Metadata): Option[FileMeta] =
  ## Ported from `get_thumbnail_generate`.
  none(FileMeta)

proc getThumbnailGenerate*(self: Dim; Mxc: Mxc<'_>; Dim: Dim; data: Metadata): Option[FileMeta] =
  ## Ported from `get_thumbnail_generate`.
  none(FileMeta)

proc thumbnailGenerate*(image: image::DynamicImage; requested: Dim): image::DynamicImage =
  ## Ported from `thumbnail_generate`.
  discard

proc intoFilemeta*(data: Metadata; content: seq[u8]): FileMeta =
  ## Ported from `into_filemeta`.
  discard

proc fromRuma*(width: UInt; height: UInt; method: Option[Method]) =
  ## Ported from `from_ruma`.
  discard

proc scaled*(self: Dim) =
  ## Ported from `scaled`.
  discard

proc normalized*(self: Dim) =
  ## Ported from `normalized`.
  discard

proc crop*(self: Dim): bool =
  ## Ported from `crop`.
  false
