## spaces/tests — service tests.
##
## Ported from Rust service/rooms/spaces/tests.rs
##
## Unit tests for space hierarchy functionality: pagination token
## parsing/serialization and summary child extraction.

import std/[options, json, unittest, strutils, sequtils]
import pagination_token

const
  RustPath* = "service/rooms/spaces/tests.rs"
  RustCrate* = "service"

suite "spaces":

  test "valid pagination tokens":
    ## Ported from `valid_pagination_tokens`.
    let token = fromStr("1,2,3_10_5_true")
    check token.isSome
    let t = token.get()
    check t.shortRoomIds == @[1'u64, 2'u64, 3'u64]
    check t.limit == 10
    check t.maxDepth == 5
    check t.suggestedOnly == true

    let token2 = fromStr("42_100_10_false")
    check token2.isSome
    let t2 = token2.get()
    check t2.shortRoomIds == @[42'u64]
    check t2.limit == 100
    check t2.maxDepth == 10
    check t2.suggestedOnly == false


  test "invalid pagination tokens":
    ## Ported from `invalid_pagination_tokens`.
    check fromStr("").isNone
    check fromStr("abc").isNone
    check fromStr("1_2_3").isNone  # missing field
    check fromStr("1_2_3_maybe").isNone  # invalid bool
    check fromStr("1_2_3_true_extra").isNone  # too many fields


  test "pagination token to string":
    ## Ported from `pagination_token_to_string`.
    let token = PaginationToken(
      shortRoomIds: @[1'u64, 2'u64, 3'u64],
      limit: 10,
      maxDepth: 5,
      suggestedOnly: true,
    )
    check $token == "1,2,3_10_5_true"

    let token2 = PaginationToken(
      shortRoomIds: @[42'u64],
      limit: 100,
      maxDepth: 10,
      suggestedOnly: false,
    )
    check $token2 == "42_100_10_false"


  test "pagination token roundtrip":
    ## Roundtrip test: parse → serialize → parse should be identity.
    let original = PaginationToken(
      shortRoomIds: @[5'u64, 10'u64, 15'u64],
      limit: 50,
      maxDepth: 3,
      suggestedOnly: false,
    )
    let serialized = $original
    let parsed = fromStr(serialized)
    check parsed.isSome
    let p = parsed.get()
    check p.shortRoomIds == original.shortRoomIds
    check p.limit == original.limit
    check p.maxDepth == original.maxDepth
    check p.suggestedOnly == original.suggestedOnly
