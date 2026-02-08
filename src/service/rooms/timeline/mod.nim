## timeline/mod — service module.
##
## Ported from Rust service/rooms/timeline/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/timeline/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    mutexInsert*: RoomMutexMap

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc memoryUsage*(self: Service; out: mut (dyn Write + Send) =
  ## Ported from `memory_usage`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc replacePdu*(self: Service; pduId: RawPduId; pduJson: CanonicalJsonObject) =
  ## Ported from `replace_pdu`.
  discard

proc addPduOutlier*(self: Service; eventId: string; pdu: CanonicalJsonObject) =
  ## Ported from `add_pdu_outlier`.
  discard

proc firstPduInRoom*(self: Service; roomId: string): PduEvent =
  ## Ported from `first_pdu_in_room`.
  discard

proc latestPduInRoom*(self: Service; roomId: string): PduEvent =
  ## Ported from `latest_pdu_in_room`.
  discard

proc firstItemInRoom*(self: Service; roomId: string): (PduCount =
  ## Ported from `first_item_in_room`.
  discard

proc latestItemInRoom*(self: Service; senderUser: Option[string]; roomId: string): PduEvent =
  ## Ported from `latest_item_in_room`.
  discard

proc prevShortstatehash*(self: Service; roomId: string; before: PduCount): ShortStateHash =
  ## Ported from `prev_shortstatehash`.
  discard

proc nextShortstatehash*(self: Service; roomId: string; after: PduCount): ShortStateHash =
  ## Ported from `next_shortstatehash`.
  discard

proc getShortstatehash*(self: Service; roomId: string; count: PduCount): ShortStateHash =
  ## Ported from `get_shortstatehash`.
  discard

proc prevTimelineCount*(self: Service; before: PduId): PduCount =
  ## Ported from `prev_timeline_count`.
  discard

proc nextTimelineCount*(self: Service; after: PduId): PduCount =
  ## Ported from `next_timeline_count`.
  discard

proc lastTimelineCount*(self: Service; senderUser: Option[string]; roomId: string; upperBound: Option[PduCount]): PduCount =
  ## Ported from `last_timeline_count`.
  discard

proc eachPdu*() =
  ## Ported from `each_pdu`.
  discard

proc countToId*(self: Service; roomId: string; count: PduCount; dir: Direction): RawPduId =
  ## Ported from `count_to_id`.
  discard

proc pduCountToId*(shortroomid: Shortstring; count: PduCount; dir: Direction): RawPduId =
  ## Ported from `pdu_count_to_id`.
  discard

proc getPduFromShorteventid*(self: Service; shorteventid: Shortstring): PduEvent =
  ## Ported from `get_pdu_from_shorteventid`.
  discard

proc getPdu*(self: Service; eventId: string): PduEvent =
  ## Ported from `get_pdu`.
  discard
