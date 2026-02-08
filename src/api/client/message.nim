## client/message — api module.
##
## Ported from Rust api/client/message.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/message.rs"
  RustCrate* = "api"

proc getMessageEventsRoute*() =
  ## Ported from `get_message_events_route`.
  discard

proc getMemberEvent*(services: Services; roomId: string; userId: string): Option[Raw<AnyStateEvent]> =
  ## Ported from `get_member_event`.
  none(Raw<AnyStateEvent])

proc ignoredFilter*(services: Services; item: PdusIterItem; userId: string): Option[PdusIterItem] =
  ## Ported from `ignored_filter`.
  none(PdusIterItem)

proc visibilityFilter*(services: Services; item: PdusIterItem; userId: string): Option[PdusIterItem] =
  ## Ported from `visibility_filter`.
  none(PdusIterItem)

proc eventFilter*(item: PdusIterItem; filter: RoomEventFilter): Option[PdusIterItem] =
  ## Ported from `event_filter`.
  none(PdusIterItem)
