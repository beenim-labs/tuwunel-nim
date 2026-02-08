## resolver/actual — service module.
##
## Ported from Rust service/resolver/actual.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/resolver/actual.rs"
  RustCrate* = "service"

proc toString*(): Deststring =
  ## Ported from `to_string`.
  discard

proc getActualDest*(serverName: string): ActualDest =
  ## Ported from `get_actual_dest`.
  discard

proc lookupActualDest*(serverName: string): (CachedDest =
  ## Ported from `lookup_actual_dest`.
  discard

proc resolveActualDest*(dest: string; cache: bool): CachedDest =
  ## Ported from `resolve_actual_dest`.
  discard

proc actualDest1*(hostPort: FedDest): FedDest =
  ## Ported from `actual_dest_1`.
  discard

proc actualDest2*(dest: string; cache: bool; pos: int): FedDest =
  ## Ported from `actual_dest_2`.
  discard

proc actualDest3*(host: mut Deststring; cache: bool; delegated: string): FedDest =
  ## Ported from `actual_dest_3`.
  discard

proc actualDest31*(hostAndPort: FedDest): FedDest =
  ## Ported from `actual_dest_3_1`.
  discard

proc actualDest32*(cache: bool; delegated: string; pos: int): FedDest =
  ## Ported from `actual_dest_3_2`.
  discard

proc actualDest33*(cache: bool; delegated: string; overrider: FedDest): FedDest =
  ## Ported from `actual_dest_3_3`.
  discard

proc actualDest34*(cache: bool; delegated: string): FedDest =
  ## Ported from `actual_dest_3_4`.
  discard

proc actualDest4*(host: string; cache: bool; overrider: FedDest): FedDest =
  ## Ported from `actual_dest_4`.
  discard

proc actualDest5*(dest: string; cache: bool): FedDest =
  ## Ported from `actual_dest_5`.
  discard

proc conditionalQueryAndCache*(hostname: string; port: u16; cache: bool) =
  ## Ported from `conditional_query_and_cache`.
  discard

proc conditionalQueryAndCacheOverride*(untername: string; hostname: string; port: u16; cache: bool) =
  ## Ported from `conditional_query_and_cache_override`.
  discard

proc queryAndCacheOverride*(untername: '_ str; hostname: '_ str; port: u16) =
  ## Ported from `query_and_cache_override`.
  discard

proc querySrvRecord*(hostname: '_ str): Option[FedDest] =
  ## Ported from `query_srv_record`.
  none(FedDest)

proc handleResolveError*(e: ResolveError; host: '_ str) =
  ## Ported from `handle_resolve_error`.
  discard

proc validateDest*(dest: string) =
  ## Ported from `validate_dest`.
  discard

proc validateDestIpLiteral*(dest: string) =
  ## Ported from `validate_dest_ip_literal`.
  discard
