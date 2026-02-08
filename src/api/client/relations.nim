## client/relations — api module.
##
## Ported from Rust api/client/relations.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/relations.rs"
  RustCrate* = "api"

proc getRelatingEventsWithRelTypeAndEventTypeRoute*() =
  ## Ported from `get_relating_events_with_rel_type_and_event_type_route`.
  discard

proc getRelatingEventsWithRelTypeRoute*() =
  ## Ported from `get_relating_events_with_rel_type_route`.
  discard

proc getRelatingEventsRoute*() =
  ## Ported from `get_relating_events_route`.
  discard

proc paginateRelationsWithFilter*(services: Services; senderUser: string; roomId: string; target: string; filterEventType: Option[TimelineEventType]; filterRelType: Option[RelationType]; from: Option[string]; to: Option[string]; limit: Option[UInt]; recurse: bool; dir: Direction): get_relating_events::v1::Response =
  ## Ported from `paginate_relations_with_filter`.
  discard
