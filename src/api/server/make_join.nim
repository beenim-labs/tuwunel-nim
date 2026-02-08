## server/make_join — api module.
##
## Ported from Rust api/server/make_join.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/make_join.rs"
  RustCrate* = "api"

proc createJoinEventTemplateRoute*() =
  ## Ported from `create_join_event_template_route`.
  discard

proc userCanPerformRestrictedJoin*(services: Services; userId: string; roomId: string; roomVersionId: RoomVersionId): bool =
  ## Ported from `user_can_perform_restricted_join`.
  false
