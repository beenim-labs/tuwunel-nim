## sync/mod — service module.
##
## Ported from Rust service/sync/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/sync/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

type
  Connection* = ref object
    globalsince*: uint64
    nextBatch*: uint64
    lists*: Lists
    extensions*: request::Extensions
    subscriptions*: Subscriptions
    rooms*: Rooms

type
  Room* = ref object
    roomsince*: uint64

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc clearConnections*(self: Service; userId: Option[string]; deviceId: Option[DeviceId]; connId: Option[ConnectionId]) =
  ## Ported from `clear_connections`.
  discard

proc dropConnection*(self: Service; key: ConnectionKey) =
  ## Ported from `drop_connection`.
  discard

proc loadOrInitConnection*(self: Service; key: ConnectionKey): ConnectionVal =
  ## Ported from `load_or_init_connection`.
  discard

proc loadConnection*(self: Service; key: ConnectionKey): ConnectionVal =
  ## Ported from `load_connection`.
  discard

proc getLoadedConnection*(self: Service; key: ConnectionKey): ConnectionVal =
  ## Ported from `get_loaded_connection`.
  discard

proc listLoadedConnections*(self: Service): seq[ConnectionKey] =
  ## Ported from `list_loaded_connections`.
  @[]

proc listStoredConnections*(self: Service): impl Stream<Item = ConnectionKey> =
  ## Ported from `list_stored_connections`.
  discard

proc isConnectionLoaded*(self: Service; key: ConnectionKey): bool =
  ## Ported from `is_connection_loaded`.
  false

proc isConnectionStored*(self: Service; key: ConnectionKey): bool =
  ## Ported from `is_connection_stored`.
  false

proc store*(self: Service; service: Service; key: ConnectionKey) =
  ## Ported from `store`.
  discard

proc updateRoomsPrologue*(self: Service; retardSince: Option[uint64]) =
  ## Ported from `update_rooms_prologue`.
  discard

proc updateCache*(self: Service; request: Request) =
  ## Ported from `update_cache`.
  discard

proc updateCacheLists*(request: Request; cached: mut Self) =
  ## Ported from `update_cache_lists`.
  discard

proc updateCacheList*(request: request::List; cached: mut request::List) =
  ## Ported from `update_cache_list`.
  discard

proc updateCacheSubscriptions*(request: Request; cached: mut Self) =
  ## Ported from `update_cache_subscriptions`.
  discard

proc updateCacheExtensions*(request: Request; cached: mut Self) =
  ## Ported from `update_cache_extensions`.
  discard

proc updateCacheAccountData*(request: AccountData; cached: mut AccountData) =
  ## Ported from `update_cache_account_data`.
  discard

proc updateCacheReceipts*(request: Receipts; cached: mut Receipts) =
  ## Ported from `update_cache_receipts`.
  discard
