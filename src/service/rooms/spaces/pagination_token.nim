## spaces/pagination_token — service module.
##
## Ported from Rust service/rooms/spaces/pagination_token.rs
##
## Pagination token for space hierarchy: encodes/decodes the current
## position in a hierarchy traversal as a compact string. Format:
## "short_room_ids_comma_separated_limit_max_depth_suggested_only"

import std/[options, strutils, sequtils]

const
  RustPath* = "service/rooms/spaces/pagination_token.rs"
  RustCrate* = "service"

type
  PaginationToken* = object
    ## Path down the hierarchy of the room to start the response at,
    ## excluding the root space.
    shortRoomIds*: seq[uint64]
    limit*: uint64
    maxDepth*: uint64
    suggestedOnly*: bool

proc fromStr*(value: string): Option[PaginationToken] =
  ## Ported from `from_str`.
  ##
  ## Parses a pagination token string. Format:
  ## "shortRoomId1,shortRoomId2_limit_maxDepth_suggestedOnly"

  let parts = value.split('_')
  if parts.len != 4:
    return none(PaginationToken)

  # Parse short room IDs (comma-separated u64 values)
  var shortRoomIds: seq[uint64] = @[]
  if parts[0].len > 0:
    for roomStr in parts[0].split(','):
      try:
        shortRoomIds.add(parseUInt(roomStr).uint64)
      except ValueError:
        return none(PaginationToken)

  # Parse limit
  var limit: uint64
  try:
    limit = parseUInt(parts[1]).uint64
  except ValueError:
    return none(PaginationToken)

  # Parse max_depth
  var maxDepth: uint64
  try:
    maxDepth = parseUInt(parts[2]).uint64
  except ValueError:
    return none(PaginationToken)

  # Parse suggested_only
  var suggestedOnly: bool
  case parts[3]
  of "true":
    suggestedOnly = true
  of "false":
    suggestedOnly = false
  else:
    return none(PaginationToken)

  some(PaginationToken(
    shortRoomIds: shortRoomIds,
    limit: limit,
    maxDepth: maxDepth,
    suggestedOnly: suggestedOnly,
  ))


proc `$`*(token: PaginationToken): string =
  ## Ported from `Display::fmt`.
  ## Serializes a pagination token to its string representation.

  let shortRoomIds = token.shortRoomIds.mapIt($it).join(",")
  shortRoomIds & "_" & $token.limit & "_" & $token.maxDepth & "_" & $token.suggestedOnly
