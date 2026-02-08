## spaces/tests — service module.
##
## Ported from Rust service/rooms/spaces/tests.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/spaces/tests.rs"
  RustCrate* = "service"

proc getSummaryChildren*() =
  ## Ported from `get_summary_children`.
  discard

proc invalidPaginationTokens*() =
  ## Ported from `invalid_pagination_tokens`.
  discard

proc tokenIsErr*(token: string) =
  ## Ported from `token_is_err`.
  discard

proc validPaginationTokens*() =
  ## Ported from `valid_pagination_tokens`.
  discard

proc paginationTokenToString*() =
  ## Ported from `pagination_token_to_string`.
  discard
