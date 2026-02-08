## users/mod — service module.
##
## Ported from Rust service/users/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

# import ./device

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc userIsIgnored*(self: Service; senderUser: string; recipientUser: string): bool =
  ## Ported from `user_is_ignored`.
  false

proc isAdmin*(self: Service; userId: string): bool =
  ## Ported from `is_admin`.
  false

proc create*(self: Service; userId: string; password: Option[string]; origin: Option[string]) =
  ## Ported from `create`.
  discard

proc deactivateAccount*(self: Service; userId: string) =
  ## Ported from `deactivate_account`.
  discard

proc exists*(self: Service; userId: string): bool =
  ## Ported from `exists`.
  false

proc isDeactivated*(self: Service; userId: string): bool =
  ## Ported from `is_deactivated`.
  false

proc isActive*(self: Service; userId: string): bool =
  ## Ported from `is_active`.
  false

proc isActiveLocal*(self: Service; userId: string): bool =
  ## Ported from `is_active_local`.
  false

proc count*(self: Service): int =
  ## Ported from `count`.
  0

proc stream*(self: Service): impl Stream<Item = string> + Send =
  ## Ported from `stream`.
  discard

proc listLocalUsers*(self: Service): impl Stream<Item = string> + Send + '_ =
  ## Ported from `list_local_users`.
  discard

proc origin*(self: Service; userId: string): string =
  ## Ported from `origin`.
  ""

proc passwordHash*(self: Service; userId: string): string =
  ## Ported from `password_hash`.
  ""

proc setPassword*(self: Service; userId: string; password: Option[string]) =
  ## Ported from `set_password`.
  discard

proc createFilter*(self: Service; userId: string; filter: FilterDefinition): string =
  ## Ported from `create_filter`.
  ""

proc getFilter*(self: Service; userId: string; filterId: string): FilterDefinition =
  ## Ported from `get_filter`.
  discard

proc createOpenidToken*(self: Service; userId: string; token: string): uint64 =
  ## Ported from `create_openid_token`.
  0

proc findFromOpenidToken*(self: Service; token: string): string =
  ## Ported from `find_from_openid_token`.
  ""
