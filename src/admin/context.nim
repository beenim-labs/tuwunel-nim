## admin/context — admin module.
##
## Ported from Rust admin/context.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/context.rs"
  RustCrate* = "admin"

proc writeFmt*(arguments: fmt::Arguments<'_>): impl Future<Output = > + Send + '_ + use<'_> =
  ## Ported from `write_fmt`.
  discard

proc writeString*(s: string) =
  ## Ported from `write_string`.
  discard
