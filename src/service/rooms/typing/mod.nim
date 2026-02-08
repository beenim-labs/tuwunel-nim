## typing/mod — service module.
##
## Ported from Rust service/rooms/typing/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/typing/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    typing*: RwLock<BTreeMap<string
    lastTypingUpdate*: RwLock<BTreeMap<string
    typingUpdateSender*: broadcast::Sender<string>

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc typingAdd*(self: Service; userId: string; roomId: string; timeout: uint64) =
  ## Ported from `typing_add`.
  discard

proc typingRemove*(self: Service; userId: string; roomId: string) =
  ## Ported from `typing_remove`.
  discard

proc waitForUpdate*(self: Service; roomId: string) =
  ## Ported from `wait_for_update`.
  discard

proc typingsMaintain*(self: Service; roomId: string) =
  ## Ported from `typings_maintain`.
  discard

proc lastTypingUpdate*(self: Service; roomId: string): uint64 =
  ## Ported from `last_typing_update`.
  0

proc typingUsersForUser*(self: Service; roomId: string; senderUser: string): seq[string] =
  ## Ported from `typing_users_for_user`.
  @[]

proc federationSend*(self: Service; roomId: string; userId: string; typing: bool) =
  ## Ported from `federation_send`.
  discard
