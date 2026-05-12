const
  RustPath* = "api/client/space.rs"
  RustCrate* = "api"
  HierarchyLimitDefault* = 10
  HierarchyLimitMax* = 100
  HierarchyDepthDefault* = 3
  HierarchyDepthMax* = 10

import std/json

type
  SpacePolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc hierarchyLimit*(limit: int): int =
  if limit <= 0:
    HierarchyLimitDefault
  else:
    min(limit, HierarchyLimitMax)

proc hierarchyDepth*(depth: int): int =
  if depth <= 0:
    HierarchyDepthDefault
  else:
    min(depth, HierarchyDepthMax)

proc hierarchyResponse*(rooms: JsonNode; nextBatch = ""): JsonNode =
  result = %*{"rooms": if rooms.isNil: newJArray() else: rooms.copy()}
  if nextBatch.len > 0:
    result["next_batch"] = %nextBatch

proc hierarchyAccessPolicy*(roomExists: bool; canView: bool): SpacePolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canView:
    return (false, "M_FORBIDDEN", "The requested room is inaccessible.")
  (true, "", "")
