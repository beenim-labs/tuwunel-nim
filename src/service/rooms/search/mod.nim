## search/mod — service module.
##
## Ported from Rust service/rooms/search/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/search/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

type
  RoomQuery* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc indexPdu*(self: Service; shortroomid: Shortstring; pduId: RawPduId; messageBody: string) =
  ## Ported from `index_pdu`.
  discard

proc deindexPdu*(self: Service; shortroomid: Shortstring; pduId: RawPduId; messageBody: string) =
  ## Ported from `deindex_pdu`.
  discard

proc searchPduIds*(self: Service; query: RoomQuery<'_>): impl Stream<Item = RawPduId + Send + '_ + use<'_>> =
  ## Ported from `search_pdu_ids`.
  discard

proc searchPduIdsQueryRoom*(self: Service; query: RoomQuery<'_>; shortroomid: Shortstring): seq[Vec<RawPduId]> =
  ## Ported from `search_pdu_ids_query_room`.
  @[]

proc searchPduIdsQueryWord*(self: Service; shortroomid: Shortstring; word: string): impl Stream<Item = Val<'_>> + Send + '_ + use<'_> =
  ## Ported from `search_pdu_ids_query_word`.
  discard

proc deleteAllSearchTokenidsForRoom*(self: Service; roomId: string) =
  ## Ported from `delete_all_search_tokenids_for_room`.
  discard

proc tokenize*(body: string): impl Iterator<Item = string> + Send + '_ =
  ## Ported from `tokenize`.
  discard

proc makeTokenid*(shortroomid: Shortstring; word: string; pduId: RawPduId): TokenId =
  ## Ported from `make_tokenid`.
  discard

proc makePrefix*(shortroomid: Shortstring; word: string): TokenId =
  ## Ported from `make_prefix`.
  discard

proc prefixLen*(word: string): int =
  ## Ported from `prefix_len`.
  0
