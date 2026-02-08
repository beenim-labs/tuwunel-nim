## media/blurhash — service module.
##
## Ported from Rust service/media/blurhash.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/media/blurhash.rs"
  RustCrate* = "service"

type
  BlurhashingError* = enum
    hashingliberror
    box
    error
    send
    imageerror
    box
    imageerror
    imagetoolarge

type
  BlurhashConfig* = ref object
    componentsX*: uint32
    componentsY*: uint32
    sizeLimit*: uint64

proc createBlurhash*(self: BlurhashConfig; File: [u8]; ContentType: Option[string]; FileName: Option[string]): Option[string] =
  ## Ported from `create_blurhash`.
  none(string)

proc createBlurhash*(self: BlurhashConfig; file: [u8]; contentType: Option[string]; fileName: Option[string]): Option[string] =
  ## Ported from `create_blurhash`.
  none(string)

proc getBlurhashFromRequest*(data: [u8]; mime: Option[string]; filename: Option[string]; config: BlurhashConfig): string =
  ## Ported from `get_blurhash_from_request`.
  ""

proc getFormatFromDataMimeAndFilename*(data: [u8]; mime: Option[string]; filename: Option[string]): image::ImageFormat =
  ## Ported from `get_format_from_data_mime_and_filename`.
  discard

proc getImageDecoderWithFormatAndData*(imageFormat: image::ImageFormat; data: [u8]) =
  ## Ported from `get_image_decoder_with_format_and_data`.
  discard

proc blurhashAnImage*(image: image::DynamicImage; blurhashConfig: BlurhashConfig): string =
  ## Ported from `blurhash_an_image`.
  ""

proc from*(value: CoreBlurhashConfig) =
  ## Ported from `from`.
  discard

proc from*(value: image::ImageError) =
  ## Ported from `from`.
  discard

proc from*(value: blurhash::Error) =
  ## Ported from `from`.
  discard
