## debug/tester — admin module.
##
## Ported from Rust admin/debug/tester.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/debug/tester.rs"
  RustCrate* = "admin"

proc panic*() =
  ## Ported from `panic`.
  discard

proc failure*() =
  ## Ported from `failure`.
  discard

proc tester*() =
  ## Ported from `tester`.
  discard

proc timer*() =
  ## Ported from `timer`.
  discard

proc timed*(body: [string]) =
  ## Ported from `timed`.
  discard
