## alias/mod — service module.
##
## Ported from Rust service/rooms/alias/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/alias/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc setAlias*(self: Service; alias: RoomAliasId; roomId: string; userId: string) =
  ## Ported from `set_alias`.
  discard

proc removeAlias*(self: Service; alias: RoomAliasId; userId: string) =
  ## Ported from `remove_alias`.
  discard

proc maybeResolve*(self: Service; room: RoomOrAliasId): string =
  ## Ported from `maybe_resolve`.
  ""

proc maybeResolveWithServers*(self: Service; room: RoomOrAliasId; servers: Option[[string]]): (string)> =
  ## Ported from `maybe_resolve_with_servers`.
  discard

proc resolveAlias*(self: Service; roomAlias: RoomAliasId): (string)> =
  ## Ported from `resolve_alias`.
  discard

proc remoteResolve*(self: Service; roomAlias: RoomAliasId): (string)> =
  ## Ported from `remote_resolve`.
  discard

proc resolveLocalAlias*(self: Service; alias: RoomAliasId): string =
  ## Ported from `resolve_local_alias`.
  ""

proc allLocalAliases*(self: Service): impl Stream<Item = (string, string)> + Send + '_ =
  ## Ported from `all_local_aliases`.
  discard

proc userCanRemoveAlias*(self: Service; alias: RoomAliasId; userId: string): bool =
  ## Ported from `user_can_remove_alias`.
  false

proc whoCreatedAlias*(self: Service; alias: RoomAliasId): string =
  ## Ported from `who_created_alias`.
  ""

proc resolveAppserviceAlias*(self: Service; roomAlias: RoomAliasId): string =
  ## Ported from `resolve_appservice_alias`.
  ""

proc checkAliasLocal*(self: Service; alias: RoomAliasId) =
  ## Ported from `check_alias_local`.
  discard

proc appserviceChecks*(self: Service; roomAlias: RoomAliasId; appserviceInfo: Option[RegistrationInfo]) =
  ## Ported from `appservice_checks`.
  discard
