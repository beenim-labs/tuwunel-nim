import std/[json, unittest]

import "service/account_data/mod" as account_data_service
import service/account_data/direct as account_data_direct
import service/account_data/room_tags as account_data_tags

suite "Service account data parity":
  test "update get changes delete and erase follow Rust account data storage semantics":
    var store = account_data_service.initAccountDataStore()
    let userId = "@alice:example.test"
    let roomId = "!room:example.test"

    let bad = account_data_service.update(store, "", userId, "m.direct", %*{"content": {}})
    check not bad.ok
    check bad.err == "Account data doesn't have all required fields."

    check account_data_service.updateContent(
      store,
      "",
      userId,
      "m.direct",
      %*{"@bob:example.test": [roomId]},
    ).ok
    check account_data_service.lastCount(store, "", userId).count == 1'u64
    check account_data_direct.isDirect(store, userId, roomId)

    let raw = account_data_service.getRaw(store, "", userId, "m.direct")
    check raw.ok
    check raw.event["type"].getStr == "m.direct"
    check raw.event["content"]["@bob:example.test"][0].getStr == roomId

    let firstDelta = account_data_service.changesSince(store, "", userId, 0'u64)
    check firstDelta.len == 1
    check firstDelta[0]["type"].getStr == "m.direct"

    check account_data_service.updateContent(
      store,
      "",
      userId,
      "m.direct",
      %*{"@bob:example.test": ["!other:example.test"]},
    ).ok
    let replacementDelta = account_data_service.changesSince(store, "", userId, 0'u64)
    check replacementDelta.len == 1
    check replacementDelta[0]["content"]["@bob:example.test"][0].getStr == "!other:example.test"
    check account_data_service.changesSince(store, "", userId, 1'u64).len == 1

    check account_data_service.delete(store, "", userId, "m.direct").ok
    let tombstone = account_data_service.getRaw(store, "", userId, "m.direct")
    check tombstone.ok
    check account_data_service.isTombstoneEvent(tombstone.event)
    check not account_data_service.getGlobal(store, userId, "m.direct", tombstoneIsMissing = true).ok
    check not account_data_direct.isDirect(store, userId, roomId)
    let tombstoneDelta = account_data_service.changesSince(store, "", userId, 2'u64)
    check tombstoneDelta.len == 1
    check tombstoneDelta[0]["content"].len == 0

    account_data_service.eraseUser(store, userId)
    check not account_data_service.getRaw(store, "", userId, "m.direct").ok
    check not account_data_service.lastCount(store, "", userId).ok

  test "room tag helpers update m.tag account data content":
    var store = account_data_service.initAccountDataStore()
    let userId = "@alice:example.test"
    let roomId = "!room:example.test"

    check account_data_tags.getRoomTags(store, userId, roomId).len == 0
    check account_data_tags.setRoomTag(store, userId, roomId, "m.favourite", %*{"order": 0.25}).ok
    check account_data_tags.setRoomTag(store, userId, roomId, "u.work").ok

    let tags = account_data_tags.getRoomTags(store, userId, roomId)
    check tags["m.favourite"]["order"].getFloat == 0.25
    check tags["u.work"].kind == JObject

    let raw = account_data_service.getRaw(store, roomId, userId, "m.tag")
    check raw.ok
    check raw.event["type"].getStr == "m.tag"
    check raw.event["content"]["tags"]["m.favourite"]["order"].getFloat == 0.25

    let deltas = account_data_service.changesSince(store, roomId, userId, 0'u64)
    check deltas.len == 1
    check deltas[0]["content"]["tags"].len == 2

    account_data_service.eraseUser(store, userId, roomId)
    check account_data_tags.getRoomTags(store, userId, roomId).len == 0
