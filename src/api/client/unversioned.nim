const
  RustPath* = "api/client/unversioned.rs"
  RustCrate* = "api"

import std/strutils

const
  ClientApiPrefixes* = [
    "/_matrix/client/v3/",
    "/_matrix/client/r0/",
    "/_matrix/client/v1/",
    "/_matrix/client/unstable/",
  ]

proc trimClientPath*(path: string): string =
  for prefix in ClientApiPrefixes:
    if path.startsWith(prefix):
      return path[prefix.len .. ^1]
  path.strip(chars = {'/'})

proc isClientApiPath*(path: string): bool =
  for prefix in ClientApiPrefixes:
    if path.startsWith(prefix):
      return true
  false
