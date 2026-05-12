const
  RustPath* = "api/server/utils.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[strutils, uri]

proc trimFederationPath*(path: string): string =
  const Prefixes = [
    "/_matrix/federation/v1/",
    "/_matrix/federation/v2/",
  ]
  for prefix in Prefixes:
    if path.startsWith(prefix):
      return path[prefix.len .. ^1]
  ""

proc federationPathParts*(path: string): seq[string] =
  result = @[]
  let trimmed = trimFederationPath(path)
  if trimmed.len == 0:
    return
  for part in trimmed.split('/'):
    result.add(decodeUrl(part))
