## debug/commands — admin module.
##
## Ported from Rust admin/debug/commands.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/debug/commands.rs"
  RustCrate* = "admin"

proc echo*(message: seq[string]) =
  ## Ported from `echo`.
  discard

proc getAuthChain*(eventId: string) =
  ## Ported from `get_auth_chain`.
  discard

proc parsePdu*() =
  ## Ported from `parse_pdu`.
  discard

proc getPdu*(eventId: string) =
  ## Ported from `get_pdu`.
  discard

proc getShortPdu*(shortroomid: Shortstring; count: int64) =
  ## Ported from `get_short_pdu`.
  discard

proc getRemotePduList*(server: string; force: bool) =
  ## Ported from `get_remote_pdu_list`.
  discard

proc getRemotePdu*(eventId: string; server: string) =
  ## Ported from `get_remote_pdu`.
  discard

proc getRoomState*(room: OwnedRoomOrAliasId) =
  ## Ported from `get_room_state`.
  discard

proc ping*(server: string) =
  ## Ported from `ping`.
  discard

proc forceDeviceListUpdates*() =
  ## Ported from `force_device_list_updates`.
  discard

proc changeLogLevel*(filter: Option[string]; reset: bool) =
  ## Ported from `change_log_level`.
  discard

proc signJson*() =
  ## Ported from `sign_json`.
  discard

proc verifyJson*() =
  ## Ported from `verify_json`.
  discard

proc verifyPdu*(eventId: string) =
  ## Ported from `verify_pdu`.
  discard

proc firstPduInRoom*(roomId: string) =
  ## Ported from `first_pdu_in_room`.
  discard

proc latestPduInRoom*(roomId: string) =
  ## Ported from `latest_pdu_in_room`.
  discard

proc forceSetRoomStateFromServer*(roomId: string; serverName: string) =
  ## Ported from `force_set_room_state_from_server`.
  discard

proc getSigningKeys*(serverName: Option[string]; notary: Option[string]; query: bool) =
  ## Ported from `get_signing_keys`.
  discard

proc getVerifyKeys*(serverName: Option[string]) =
  ## Ported from `get_verify_keys`.
  discard

proc resolveTrueDestination*(serverName: string; noCache: bool) =
  ## Ported from `resolve_true_destination`.
  discard
