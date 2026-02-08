## admin/mod — service module.
##
## Ported from Rust service/admin/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/admin/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    handle*: RwLock<Option[Processor]>
    complete*: StdRwLock<Option[Completer]>
    adminAlias*: OwnedRoomAliasId
    console*: console::Console

type
  CommandInput* = ref object
    command*: string
    replyId*: Option[string]

# import ./console
# import ./create

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: Service) =
  ## Ported from `worker`.
  discard

proc interrupt*(self: Service) =
  ## Ported from `interrupt`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc notice*(self: Service; body: string) =
  ## Ported from `notice`.
  discard

proc sendText*(self: Service; body: string) =
  ## Ported from `send_text`.
  discard

proc sendMessage*(self: Service; messageContent: RoomMessageEventContent) =
  ## Ported from `send_message`.
  discard

proc command*(self: Service; command: string; replyId: Option[string]) =
  ## Ported from `command`.
  discard

proc commandInPlace*(self: Service; command: string; replyId: Option[string]): Processor =
  ## Ported from `command_in_place`.
  discard

proc completeCommand*(self: Service; command: string): Option[string] =
  ## Ported from `complete_command`.
  none(string)

proc handleSignal*(self: Service; sig: 'static str) =
  ## Ported from `handle_signal`.
  discard

proc handleCommand*(self: Service; command: CommandInput) =
  ## Ported from `handle_command`.
  discard

proc handleCommandOutput*(self: Service; content: RoomMessageEventContent) =
  ## Ported from `handle_command_output`.
  discard

proc processCommand*(self: Service; command: CommandInput): Processor =
  ## Ported from `process_command`.
  discard

proc userIsAdmin*(self: Service; userId: string): bool =
  ## Ported from `user_is_admin`.
  false

proc getAdminRoom*(self: Service): string =
  ## Ported from `get_admin_room`.
  ""

proc handleResponse*(self: Service; content: RoomMessageEventContent) =
  ## Ported from `handle_response`.
  discard

proc respondToRoom*(self: Service; content: RoomMessageEventContent; roomId: string; userId: string) =
  ## Ported from `respond_to_room`.
  discard

proc handleResponseError*(self: Service; e: Error; roomId: string; userId: string; stateLock: RoomMutexGuard) =
  ## Ported from `handle_response_error`.
  discard

proc isAdminRoom*(self: Service; roomId: string): bool =
  ## Ported from `is_admin_room`.
  false
