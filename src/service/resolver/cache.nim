## resolver/cache — service module.
##
## Ported from Rust service/resolver/cache.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/cache.rs"
  RustCrate* = "service"

type
  Cache* = ref object
    discard

type
  CachedDest* = ref object
    dest*: FedDest
    host*: Deststring
    expire*: SystemTime

type
  CachedOverride* = ref object
    ips*: IpAddrs
    port*: u16
    expire*: SystemTime
    overriding*: Option[Deststring]

proc clear*(self: Cache) =
  ## Ported from `clear`.
  discard

proc clearDestinations*(self: Cache) =
  ## Ported from `clear_destinations`.
  discard

proc clearOverrides*(self: Cache) =
  ## Ported from `clear_overrides`.
  discard

proc delDestination*(self: Cache; name: string) =
  ## Ported from `del_destination`.
  discard

proc delOverride*(self: Cache; name: string) =
  ## Ported from `del_override`.
  discard

proc setDestination*(self: Cache; name: string; dest: CachedDest) =
  ## Ported from `set_destination`.
  discard

proc setOverride*(self: Cache; name: string; over: CachedOverride) =
  ## Ported from `set_override`.
  discard

proc hasDestination*(self: Cache; destination: string): bool =
  ## Ported from `has_destination`.
  false

proc hasOverride*(self: Cache; destination: string): bool =
  ## Ported from `has_override`.
  false

proc getDestination*(self: Cache; name: string): CachedDest =
  ## Ported from `get_destination`.
  discard

proc getOverride*(self: Cache; name: string): CachedOverride =
  ## Ported from `get_override`.
  discard

proc destinations*(self: Cache): impl Stream<Item = (string, CachedDest)> + Send + '_ =
  ## Ported from `destinations`.
  discard

proc overrides*(self: Cache): impl Stream<Item = (string, CachedOverride)> + Send + '_ =
  ## Ported from `overrides`.
  discard

proc valid*(self: Cache): bool =
  ## Ported from `valid`.
  false

proc defaultExpire*(): SystemTime =
  ## Ported from `default_expire`.
  discard

proc size*(self: Cache): int =
  ## Ported from `size`.
  0

proc valid*(self: Cache): bool =
  ## Ported from `valid`.
  false

proc defaultExpire*(): SystemTime =
  ## Ported from `default_expire`.
  discard

proc size*(self: Cache): int =
  ## Ported from `size`.
  0
