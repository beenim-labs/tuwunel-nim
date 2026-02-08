## server/send — api module.
##
## Ported from Rust api/server/send.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/send.rs"
  RustCrate* = "api"

proc sendTransactionMessageRoute*() =
  ## Ported from `send_transaction_message_route`.
  discard

proc handle*(services: Services; client: IpAddr; origin: string; started: Instant; pdus: impl Stream<Item = Pdu> + Send; edus: impl Stream<Item = Edu> + Send): ResolvedMap =
  ## Ported from `handle`.
  discard

proc handleRoom*(services: Services; Client: IpAddr; origin: string; txnStartTime: Instant; roomId: string; pdus: impl Iterator<Item = (int) =
  ## Ported from `handle_room`.
  discard

proc handleEdu*(services: Services; client: IpAddr; origin: string; i: int; edu: Edu) =
  ## Ported from `handle_edu`.
  discard

proc handleEduPresence*(services: Services; Client: IpAddr; origin: string; presence: PresenceContent) =
  ## Ported from `handle_edu_presence`.
  discard

proc handleEduPresenceUpdate*(services: Services; origin: string; update: PresenceUpdate) =
  ## Ported from `handle_edu_presence_update`.
  discard

proc handleEduReceipt*(services: Services; Client: IpAddr; origin: string; receipt: ReceiptContent) =
  ## Ported from `handle_edu_receipt`.
  discard

proc handleEduReceiptRoom*(services: Services; origin: string; roomId: string; roomUpdates: ReceiptMap) =
  ## Ported from `handle_edu_receipt_room`.
  discard

proc handleEduReceiptRoomUser*(services: Services; origin: string; roomId: string; userId: string; userUpdates: ReceiptData) =
  ## Ported from `handle_edu_receipt_room_user`.
  discard

proc handleEduTyping*(services: Services; Client: IpAddr; origin: string; typing: TypingContent) =
  ## Ported from `handle_edu_typing`.
  discard

proc handleEduDeviceListUpdate*(services: Services; Client: IpAddr; origin: string; content: DeviceListUpdateContent) =
  ## Ported from `handle_edu_device_list_update`.
  discard

proc handleEduDirectToDevice*(services: Services; Client: IpAddr; origin: string; content: DirectDeviceContent) =
  ## Ported from `handle_edu_direct_to_device`.
  discard

proc handleEduDirectToDeviceEvent*(services: Services; targetUserId: string; sender: string; targetDeviceIdMaybe: DeviceIdOrAllDevices; evType: string; event: serde_json::Value) =
  ## Ported from `handle_edu_direct_to_device_event`.
  discard

proc handleEduSigningKeyUpdate*(services: Services; Client: IpAddr; origin: string; content: SigningKeyUpdateContent) =
  ## Ported from `handle_edu_signing_key_update`.
  discard
