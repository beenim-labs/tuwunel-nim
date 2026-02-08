## Event filtering / matching logic.
##
## Ported from Rust core/matrix/event/filter.rs — provides event filtering
## by sender, room, type, and URL presence, matching the Matrix Client-Server
## API filter specification.

import std/[json, options, sequtils]
import ../event

const
  RustPath* = "core/matrix/event/filter.rs"
  RustCrate* = "core"

type
  ## URL filter mode for events.
  UrlFilter* = enum
    ufEventsWithUrl
    ufEventsWithoutUrl

  ## Room event filter matching the Matrix spec.
  RoomEventFilter* = object
    senders*: Option[seq[string]]
    notSenders*: seq[string]
    rooms*: Option[seq[string]]
    notRooms*: seq[string]
    types*: Option[seq[string]]
    notTypes*: seq[string]
    urlFilter*: Option[UrlFilter]

  ## Room filter.
  RoomFilter* = object
    rooms*: Option[seq[string]]
    notRooms*: seq[string]

proc matchesSender*(event: Event; filter: RoomEventFilter): bool =
  ## Check if event sender matches the filter.
  if filter.notSenders.anyIt(it == event.sender):
    return false
  if filter.senders.isSome:
    if not filter.senders.get().anyIt(it == event.sender):
      return false
  true

proc matchesRoom*(event: Event; filter: RoomEventFilter): bool =
  ## Check if event room matches the filter.
  if filter.notRooms.anyIt(it == event.roomId):
    return false
  if filter.rooms.isSome:
    if not filter.rooms.get().anyIt(it == event.roomId):
      return false
  true

proc matchesType*(event: Event; filter: RoomEventFilter): bool =
  ## Check if event type matches the filter.
  let kind = event.eventType
  if filter.notTypes.anyIt(it == kind):
    return false
  if filter.types.isSome:
    if not filter.types.get().anyIt(it == kind):
      return false
  true

proc matchesUrl*(event: Event; filter: RoomEventFilter): bool =
  ## Check if event URL presence matches the filter.
  if filter.urlFilter.isNone:
    return true
  let content = event.getContentAsValue()
  let hasUrl = content.kind == JObject and content.hasKey("url") and
               content["url"].kind == JString
  case filter.urlFilter.get()
  of ufEventsWithUrl: hasUrl
  of ufEventsWithoutUrl: not hasUrl

proc matches*(event: Event; filter: RoomEventFilter): bool =
  ## Check if an event matches all filter criteria.
  matchesSender(event, filter) and
  matchesRoom(event, filter) and
  matchesType(event, filter) and
  matchesUrl(event, filter)

proc matchesRoomId*(roomId: string; filter: RoomFilter): bool =
  ## Check if a room ID matches the room filter.
  if filter.notRooms.anyIt(it == roomId):
    return false
  if filter.rooms.isSome:
    if not filter.rooms.get().anyIt(it == roomId):
      return false
  true

proc newRoomEventFilter*(): RoomEventFilter =
  ## Create an empty (pass-all) room event filter.
  RoomEventFilter(
    senders: none(seq[string]),
    notSenders: @[],
    rooms: none(seq[string]),
    notRooms: @[],
    types: none(seq[string]),
    notTypes: @[],
    urlFilter: none(UrlFilter),
  )

proc newRoomFilter*(): RoomFilter =
  ## Create an empty (pass-all) room filter.
  RoomFilter(rooms: none(seq[string]), notRooms: @[])
