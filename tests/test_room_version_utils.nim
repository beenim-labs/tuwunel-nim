import std/[json, unittest]

import core/info/room_version as info_room_version
import core/matrix/room_version as matrix_room_version

suite "room version utility parity":
  test "rules reject unknown versions and accept known Matrix versions":
    check matrix_room_version.rules("11").ok
    check matrix_room_version.rules("3").ok
    check not matrix_room_version.rules("999").ok

  test "create content extracts room version with v11 default":
    check matrix_room_version.fromCreateContent(%*{}).roomVersion == "11"
    check matrix_room_version.fromCreateContent(%*{"room_version": "10"}).roomVersion == "10"
    check not matrix_room_version.fromCreateContent(%*{"room_version": "999"}).ok
    check matrix_room_version.fromCreateEvent(%*{"content": {"room_version": "12"}}).roomVersion == "12"

  test "supported room versions match stable and unstable policy":
    check matrix_room_version.supportedRoomVersion("11")
    check matrix_room_version.supportedRoomVersion("3")
    check not matrix_room_version.supportedRoomVersion("3", allowUnstableRoomVersions = false)
    check info_room_version.StableRoomVersions[^1] == "12"
    check info_room_version.supportedRoomVersion("12")
