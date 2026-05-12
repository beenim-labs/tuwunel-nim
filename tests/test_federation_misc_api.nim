import std/[json, unittest]

import api/server/hierarchy as server_hierarchy_api
import api/server/media as server_media_api
import api/server/publicrooms as server_publicrooms_api
import api/server/user as server_user_api
import api/server/utils as server_utils_api

suite "Federation misc API helpers":
  test "public room directory payload preserves Matrix pagination fields":
    let payload = server_publicrooms_api.publicRoomsPayload(
      %*[
        {
          "room_id": "!room:localhost",
          "num_joined_members": 2,
          "world_readable": false,
          "guest_can_join": false
        }
      ],
      3,
      "2",
      "0",
    )
    check payload.ok
    check payload.payload["chunk"].len == 1
    check payload.payload["total_room_count_estimate"].getInt() == 3
    check payload.payload["next_batch"].getStr("") == "2"
    check payload.payload["prev_batch"].getStr("") == "0"

  test "hierarchy payload exposes rooms and inaccessible children":
    let payload = server_hierarchy_api.hierarchyPayload(
      %*[{"room_id": "!space:localhost"}],
      "",
      %*["!hidden:localhost"],
    )
    check payload.ok
    check payload.payload["rooms"][0]["room_id"].getStr("") == "!space:localhost"
    check payload.payload["inaccessible_children"][0].getStr("") == "!hidden:localhost"

  test "user devices payload includes cross-signing keys when present":
    let payload = server_user_api.userDevicesPayload(
      "@alice:localhost",
      42,
      %*[{"device_id": "DEVICE", "keys": {}}],
      %*{"user_id": "@alice:localhost", "usage": ["master"]},
      %*{"user_id": "@alice:localhost", "usage": ["self_signing"]},
    )
    check payload.ok
    check payload.payload["stream_id"].getInt() == 42
    check payload.payload["devices"][0]["device_id"].getStr("") == "DEVICE"
    check payload.payload["master_key"]["usage"][0].getStr("") == "master"
    check payload.payload["self_signing_key"]["usage"][0].getStr("") == "self_signing"

  test "federation path and media parsing covers v1 and v2 routes":
    check server_utils_api.trimFederationPath("/_matrix/federation/v1/event/%24abc") ==
      "event/%24abc"
    let parts = server_utils_api.federationPathParts("/_matrix/federation/v2/media/download/media%2Fid")
    check parts == @["media", "download", "media/id"]

    let media = server_media_api.mediaPathParts(parts)
    check media.ok
    check not media.thumbnail
    check media.mediaId == "media/id"

    let thumb = server_media_api.mediaPathParts(@["media", "thumbnail", "m"])
    check thumb.ok
    check thumb.thumbnail
