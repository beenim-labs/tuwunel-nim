## state_cache/via — service module.
##
## Ported from Rust service/rooms/state_cache/via.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_cache/via.rs"
  RustCrate* = "service"

proc addServersInviteVia*(roomId: string; servers: seq[string]) =
  ## Ported from `add_servers_invite_via`.
  discard

proc serversRouteVia*(roomId: string): seq[string] =
  ## Ported from `servers_route_via`.
  @[]
