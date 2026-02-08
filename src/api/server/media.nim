## server/media — api module.
##
## Ported from Rust api/server/media.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/media.rs"
  RustCrate* = "api"

proc getContentRoute*() =
  ## Ported from `get_content_route`.
  discard

proc getContentThumbnailRoute*() =
  ## Ported from `get_content_thumbnail_route`.
  discard
