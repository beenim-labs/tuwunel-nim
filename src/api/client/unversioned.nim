## client/unversioned — api module.
##
## Ported from Rust api/client/unversioned.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/unversioned.rs"
  RustCrate* = "api"

proc getSupportedVersionsRoute*(Body: Ruma<get_supported_versions::Request>): get_supported_versions::Response =
  ## Ported from `get_supported_versions_route`.
  discard

proc tuwunelServerVersion*(): impl IntoResponse =
  ## Ported from `tuwunel_server_version`.
  discard

proc tuwunelLocalUserCount*() =
  ## Ported from `tuwunel_local_user_count`.
  discard
