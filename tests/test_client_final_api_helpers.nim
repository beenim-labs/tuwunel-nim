import std/[json, unittest]

import api/client/appservice as client_appservice
import api/client/keys as client_keys
import api/client/media as client_media
import api/client/media_legacy as client_media_legacy
import api/client/room/create as client_room_create
import api/client/unstable as client_unstable

suite "Client appservice, keys, media, room create and unstable API helpers":
  test "appservice ping helper validates registration and token":
    let ok = client_appservice.pingPolicy("as1", ["as1"], "tok", "tok")
    check ok.ok
    check client_appservice.pingResponse(17)["duration_ms"].getInt == 17

    let missing = client_appservice.pingPolicy("", ["as1"], "tok", "tok")
    check not missing.ok
    check missing.errcode == "M_NOT_FOUND"

    let unknownToken = client_appservice.pingPolicy("as1", ["as1"], "bad", "tok")
    check not unknownToken.ok
    check unknownToken.errcode == "M_UNKNOWN_TOKEN"

  test "keys helpers split ids and preserve Matrix response envelopes":
    let split = client_keys.splitKeyId("signed_curve25519:abc")
    check split.ok
    check split.algorithm == "signed_curve25519"
    check split.keyId == "abc"
    check not client_keys.splitKeyId("missing-separator").ok

    check client_keys.uploadKeysPolicy("DEVICE", %*{"one_time_keys": {}}).ok
    let badUpload = client_keys.uploadKeysPolicy("DEVICE", %*{"fallback_keys": []})
    check not badUpload.ok
    check badUpload.errcode == "M_BAD_JSON"

    let upload = client_keys.uploadKeysResponse(%*{"signed_curve25519": 2}, %*["signed_curve25519"])
    check upload["one_time_key_counts"]["signed_curve25519"].getInt == 2
    check upload["device_unused_fallback_key_types"][0].getStr == "signed_curve25519"

    let fallback = client_keys.fallbackDeviceKey("@alice:example.test", "DEVICE")
    check fallback["user_id"].getStr == "@alice:example.test"
    check fallback["device_id"].getStr == "DEVICE"

    let query = client_keys.queryKeysResponse(%*{"@alice:example.test": {"DEVICE": fallback}})
    check query["device_keys"]["@alice:example.test"]["DEVICE"]["device_id"].getStr == "DEVICE"
    check query["failures"].kind == JObject

    let claimed = client_keys.claimKeysResponse(%*{"@alice:example.test": {"DEVICE": {}}})
    check claimed["one_time_keys"].kind == JObject
    check client_keys.keyChangesResponse(%*["@alice:example.test"], nil)["left"].len == 0

    let badSigning = client_keys.uploadSigningKeysPolicy(%*{"master_key": []})
    check not badSigning.ok
    check badSigning.errcode == "M_BAD_JSON"
    check client_keys.signaturesUploadResponse()["failures"].kind == JObject
    check client_keys.signingKeysUploadResponse().kind == JObject

  test "media helpers produce modern and legacy Matrix media payloads":
    check client_media.contentUri("example.test", "media1") == "mxc://example.test/media1"
    let upload = client_media.uploadResponse("example.test", "media1", blurhash = "abc")
    check upload["content_uri"].getStr == "mxc://example.test/media1"
    check upload["blurhash"].getStr == "abc"
    check client_media.asyncUploadResponse().kind == JObject

    check client_media.mediaConfigResponse(1024)["m.upload.size"].getInt == 1024
    check client_media_legacy.legacyMediaConfigResponse(2048)["m.upload.size"].getInt == 2048

    check client_media.previewPolicy("https://example.test/page").ok
    check not client_media.previewPolicy("").ok
    check not client_media.previewPolicy("ftp://example.test/page").ok
    check client_media_legacy.legacyPreviewResponse("https://example.test/page")["og:url"].getStr == "https://example.test/page"
    check client_media.mediaNotFound().errcode == "M_NOT_FOUND"

  test "room create and unstable helpers keep response and policy contracts":
    let body = %*{
      "creation_content": {"m.federate": false},
      "invite": ["@bob:example.test", "", 42],
    }
    let creation = client_room_create.creationContent("@alice:example.test", body)
    check creation["creator"].getStr == "@alice:example.test"
    check creation["m.federate"].getBool == false
    check client_room_create.inviteList(body) == @["@bob:example.test"]
    check client_room_create.createRoomResponse("!room:example.test")["room_id"].getStr == "!room:example.test"
    check not client_room_create.roomCreatePolicy(false).ok

    check not client_unstable.mutualRoomsPolicy("@alice:example.test", "@alice:example.test").ok
    check client_unstable.mutualRoomsPolicy("@alice:example.test", "@bob:example.test").ok
    let mutual = client_unstable.mutualRoomsResponse(%*["!room:example.test"])
    check mutual["joined"][0].getStr == "!room:example.test"
    check mutual["next_batch_token"].kind == JNull
    check client_unstable.profileFieldWriteResponse().kind == JObject
