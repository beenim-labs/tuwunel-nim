## query/raw — admin module.
##
## Ported from Rust admin/query/raw.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/query/raw.rs"
  RustCrate* = "admin"

proc rawCompact*(maps: Option[seq[string]]; start: Option[string]; stop: Option[string]; from: Option[int]; into: Option[int]; parallelism: Option[int]; exhaustive: bool) =
  ## Ported from `raw_compact`.
  discard

proc rawCount*(map: Option[string]; prefix: Option[string]) =
  ## Ported from `raw_count`.
  discard

proc rawKeys*(map: string; prefix: Option[string]; limit: Option[int]; from: Option[string]; backwards: bool) =
  ## Ported from `raw_keys`.
  discard

proc rawKeysSizes*(map: Option[string]; prefix: Option[string]) =
  ## Ported from `raw_keys_sizes`.
  discard

proc rawKeysTotal*(map: Option[string]; prefix: Option[string]) =
  ## Ported from `raw_keys_total`.
  discard

proc rawValsSizes*(map: Option[string]; prefix: Option[string]) =
  ## Ported from `raw_vals_sizes`.
  discard

proc rawValsTotal*(map: Option[string]; prefix: Option[string]) =
  ## Ported from `raw_vals_total`.
  discard

proc rawIter*(map: string; prefix: Option[string]; limit: Option[int]; from: Option[string]; backwards: bool) =
  ## Ported from `raw_iter`.
  discard

proc rawDel*(map: string; key: string) =
  ## Ported from `raw_del`.
  discard

proc rawClear*(map: string; confirm: bool) =
  ## Ported from `raw_clear`.
  discard

proc rawGet*(map: string; key: string; base64: bool) =
  ## Ported from `raw_get`.
  discard

proc rawMaps*() =
  ## Ported from `raw_maps`.
  discard

proc withMapOr*(map: Option[string]; services: Services): seq[Map] =
  ## Ported from `with_map_or`.
  @[]

proc encode*(data: [u8]): string =
  ## Ported from `encode`.
  ""
