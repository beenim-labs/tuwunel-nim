import core/matrix/room_version as matrix_room_version

const
  RustPath* = "core/info/room_version.rs"
  RustCrate* = "core"
  StableRoomVersions* = matrix_room_version.StableRoomVersions
  UnstableRoomVersions* = matrix_room_version.UnstableRoomVersions
  ExperimentalRoomVersions* = matrix_room_version.ExperimentalRoomVersions

export matrix_room_version.supportedRoomVersion
export matrix_room_version.supportedRoomVersions
