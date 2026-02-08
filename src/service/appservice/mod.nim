## appservice/mod — service module.
##
## Ported from Rust service/appservice/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/appservice/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: Service) =
  ## Ported from `worker`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc initRegistrations*(self: Service) =
  ## Ported from `init_registrations`.
  discard

proc checkRegistrations*(self: Service) =
  ## Ported from `check_registrations`.
  discard

proc registerAppservice*(self: Service; registration: Registration; appserviceConfigBody: string) =
  ## Ported from `register_appservice`.
  discard

proc unregisterAppservice*(self: Service; appserviceId: string) =
  ## Ported from `unregister_appservice`.
  discard

proc getRegistration*(self: Service; id: string): Option[Registration] =
  ## Ported from `get_registration`.
  none(Registration)

proc findFromAccessToken*(self: Service; token: string): RegistrationInfo =
  ## Ported from `find_from_access_token`.
  discard

proc isExclusiveUserId*(self: Service; userId: string): bool =
  ## Ported from `is_exclusive_user_id`.
  false

proc isExclusiveAlias*(self: Service; alias: RoomAliasId): bool =
  ## Ported from `is_exclusive_alias`.
  false

proc isExclusiveRoomId*(self: Service; roomId: string): bool =
  ## Ported from `is_exclusive_room_id`.
  false

proc iterIds*(self: Service): impl Stream<Item = string> + Send =
  ## Ported from `iter_ids`.
  discard

proc iterDbIds*(self: Service): impl Stream<Item = (string> + Send =
  ## Ported from `iter_db_ids`.
  discard

proc getDbRegistration*(self: Service; id: string): Registration =
  ## Ported from `get_db_registration`.
  discard

proc read*(self: Service): impl Future<Output = RwLockReadGuard<'_, Registrations>> + Send =
  ## Ported from `read`.
  discard
