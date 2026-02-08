## Room version support — stable, unstable, and experimental versions.
##
## Ported from Rust core/info/room_version.rs — defines the supported
## Matrix room versions and their stability status.

const
  RustPath* = "core/info/room_version.rs"
  RustCrate* = "core"

type
  ## Room version stability classification.
  RoomVersionStability* = enum
    rvsStable
    rvsUnstable

  ## Room version with stability.
  RoomVersion* = tuple[id: string, stability: RoomVersionStability]

const
  ## Partially supported non-compliant room versions.
  UnstableRoomVersions*: seq[string] = @["2", "3", "4", "5"]

  ## Supported and stable room versions.
  StableRoomVersions*: seq[string] = @["6", "7", "8", "9", "10", "11", "12"]

  ## Experimental room versions under development.
  ExperimentalRoomVersions*: seq[string] = @[]

proc availableRoomVersions*(): seq[RoomVersion] =
  ## Get all available room versions with their stability.
  result = @[]
  for v in StableRoomVersions:
    result.add((id: v, stability: rvsStable))
  for v in UnstableRoomVersions:
    result.add((id: v, stability: rvsUnstable))

proc isStableRoomVersion*(version: string): bool =
  ## Check if a room version is stable.
  version in StableRoomVersions

proc isUnstableRoomVersion*(version: string): bool =
  ## Check if a room version is unstable.
  version in UnstableRoomVersions

proc isSupportedRoomVersion*(version: string;
                              allowUnstable: bool = true;
                              allowExperimental: bool = false): bool =
  ## Check if a room version is supported.
  if version in StableRoomVersions:
    return true
  if allowUnstable and version in UnstableRoomVersions:
    return true
  if allowExperimental and version in ExperimentalRoomVersions:
    return true
  false

proc supportedRoomVersions*(allowUnstable: bool = true;
                             allowExperimental: bool = false): seq[string] =
  ## Get all supported room version IDs.
  result = @[]
  for v in StableRoomVersions:
    result.add(v)
  if allowUnstable:
    for v in UnstableRoomVersions:
      result.add(v)
  if allowExperimental:
    for v in ExperimentalRoomVersions:
      result.add(v)
