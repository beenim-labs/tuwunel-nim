import std/json

const
  RustPath* = "core/matrix/room_version.rs"
  RustCrate* = "core"
  StableRoomVersions* = ["6", "7", "8", "9", "10", "11", "12"]
  UnstableRoomVersions* = ["3", "4", "5"]
  ExperimentalRoomVersions*: array[0, string] = []

type
  RoomVersionRules* = object
    roomVersion*: string
    known*: bool

  RoomVersionResult* = tuple[ok: bool, rules: RoomVersionRules, message: string]
  CreateContentResult* = tuple[ok: bool, roomVersion: string, message: string]

proc isKnownRoomVersion*(roomVersion: string): bool =
  roomVersion in StableRoomVersions or
    roomVersion in UnstableRoomVersions or
    roomVersion in ExperimentalRoomVersions

proc rules*(roomVersion: string): RoomVersionResult =
  if not roomVersion.isKnownRoomVersion:
    return (false, RoomVersionRules(), "Unknown or unsupported room version " & roomVersion)
  (true, RoomVersionRules(roomVersion: roomVersion, known: true), "")

proc fromCreateContent*(content: JsonNode): CreateContentResult =
  if content.kind != JObject:
    return (false, "", "create content must be an object")
  let roomVersion = content{"room_version"}.getStr("11")
  if not roomVersion.isKnownRoomVersion:
    return (false, "", "Unknown or unsupported room version " & roomVersion)
  (true, roomVersion, "")

proc fromCreateEvent*(event: JsonNode): CreateContentResult =
  if event.kind != JObject:
    return (false, "", "event must be an object")
  fromCreateContent(event{"content"})

proc supportedRoomVersions*(
  allowUnstableRoomVersions = true;
  allowExperimentalRoomVersions = false;
): seq[tuple[version: string, stability: string]] =
  result = @[]
  for version in StableRoomVersions:
    result.add((version, "stable"))
  if allowUnstableRoomVersions:
    for version in UnstableRoomVersions:
      result.add((version, "unstable"))
  if allowExperimentalRoomVersions:
    for version in ExperimentalRoomVersions:
      result.add((version, "unstable"))

proc supportedRoomVersion*(
  roomVersion: string;
  allowUnstableRoomVersions = true;
  allowExperimentalRoomVersions = false;
): bool =
  for item in supportedRoomVersions(allowUnstableRoomVersions, allowExperimentalRoomVersions):
    if item.version == roomVersion:
      return true
  false
