import std/[json, options, tables, unittest]

import api/client/sync/[v3, v5]

suite "Client sync API helpers":
  test "sliding sync filters select invite, DM, encrypted, tag, space and type metadata":
    var filter = listFilters()
    filter.isInvite = some(false)
    filter.isDm = some(true)
    filter.isEncrypted = some(true)
    filter.spaces = @["!space:localhost"]
    filter.tags = @["m.favourite"]
    filter.notTags = @["m.lowpriority"]
    filter.roomTypes = @[""]

    var room = roomFilterMeta("!room:localhost")
    room.membership = some("join")
    room.directAccountData = true
    room.encrypted = true
    room.parentSpaces = @["!space:localhost"]
    room.tags = @["m.favourite"]

    check filterRoom(filter, room)

    room.tags.add("m.lowpriority")
    check not filterRoom(filter, room)

    room.tags = @["m.favourite"]
    room.disabled = true
    check not filterRoomMeta(room)

    var nonDmFilter = listFilters()
    nonDmFilter.isDm = some(false)
    room.disabled = false
    room.directAccountData = false
    room.directMember = true
    check not filterRoom(nonDmFilter, room)

  test "selector ranks rooms, counts lists and returns requested window rooms":
    var conn = initSyncConnection(nextBatch = 10, globalSince = 5)
    var dmFilter = listFilters()
    dmFilter.isDm = some(true)
    conn.lists["main"] = SyncListConfig(
      filters: some(dmFilter),
      ranges: @[(0, 0)],
      roomDetails: RoomDetailConfig(
        timelineLimit: 20,
        requiredState: @[("m.room.name", "")]
      )
    )
    conn.lists["all"] = SyncListConfig(
      filters: none(ListFilters),
      ranges: @[(0, 1)],
      roomDetails: RoomDetailConfig(timelineLimit: 20)
    )

    var dmRoom = roomFilterMeta("!dm:localhost")
    dmRoom.membership = some("join")
    dmRoom.directAccountData = true
    var normalRoom = roomFilterMeta("!normal:localhost")
    normalRoom.membership = some("join")

    var lastCounts = initTable[string, uint64]()
    lastCounts["!dm:localhost"] = 30'u64
    lastCounts["!normal:localhost"] = 20'u64

    let selected = selectRooms(conn, [dmRoom, normalRoom], lastCounts)
    check selected.len == 2
    check selected[0].roomId == "!dm:localhost"
    check selected[0].ranked == 0
    check "main" in selected[0].lists
    check "all" in selected[1].lists

    let lists = responseLists(selected)
    check lists["main"].count == 1
    check lists["all"].count == 2

    let windowed = window(conn, selected)
    check windowed.len == 2
    check windowed.hasKey("!dm:localhost")
    check windowed.hasKey("!normal:localhost")

    var roomsByList = initOrderedTable[string, seq[string]]()
    roomsByList["main"] = @["!dm:localhost"]
    roomsByList["all"] = @["!dm:localhost", "!normal:localhost"]
    let listJson = listResponseJson(lists, roomsByList)
    check listJson["main"]["count"].getInt == 1
    check listJson["main"]["ops"][0]["room_ids"][0].getStr == "!dm:localhost"

  test "room and v5 response payloads preserve Matrix sliding-sync fields":
    var room = syncRoomInput("!dm:localhost")
    room.initial = true
    room.lists = @["main"]
    room.membership = some("join")
    room.name = "Direct chat"
    room.isDm = some(true)
    room.heroes = @["@alice:localhost"]
    room.requiredState = @[%*{"type": "m.room.name", "content": {"name": "Direct chat"}}]
    room.timeline = @[%*{"type": "m.room.message", "content": {"body": "hello"}}]
    room.prevBatch = "s0"
    room.numLive = some(1)
    room.bumpStamp = 42'u64
    room.joinedCount = some(2)
    room.unreadNotifications = UnreadNotifications(highlightCount: 1, notificationCount: 3)

    let payload = roomPayload(room)
    check payload["initial"].getBool
    check payload["membership"].getStr == "join"
    check payload["is_dm"].getBool
    check payload["required_state"].len == 1
    check payload["timeline"][0]["content"]["body"].getStr == "hello"
    check payload["unread_notifications"]["notification_count"].getInt == 3

    let rooms = roomsPayload([room])
    let response = syncV5Response(
      12'u64,
      %*{"main": {"count": 1}},
      rooms,
      extensionsPayload(allExtensionsEnabled()),
      txnId = "txn-1"
    )
    check response["pos"].getStr == "12"
    check response["rooms"]["!dm:localhost"]["name"].getStr == "Direct chat"
    check response["txn_id"].getStr == "txn-1"
    check not isEmptyResponse(response)

  test "extension helpers emit account data, receipts, typing, to-device and e2ee sections":
    var accountRooms = initTable[string, seq[JsonNode]]()
    accountRooms["!dm:localhost"] = @[%*{"type": "m.tag", "content": {"tags": {}}}]
    let account = accountDataPayload([%*{"type": "m.direct", "content": {}}], accountRooms)
    check account["global"][0]["type"].getStr == "m.direct"
    check account["rooms"]["!dm:localhost"][0]["type"].getStr == "m.tag"

    var receiptRooms = initTable[string, JsonNode]()
    receiptRooms["!dm:localhost"] = %*{"content": {"$event": {"m.read": {}}}}
    let receiptExt = receiptsPayload(receiptRooms)
    check receiptExt["rooms"]["!dm:localhost"]["content"].hasKey("$event")

    var typingRooms = initTable[string, seq[string]]()
    typingRooms["!dm:localhost"] = @["@alice:localhost"]
    let typingExt = typingPayload(typingRooms)
    check typingExt["rooms"]["!dm:localhost"]["type"].getStr == "m.typing"
    check typingExt["rooms"]["!dm:localhost"]["content"]["user_ids"][0].getStr == "@alice:localhost"

    check toDeviceSince("99", 7'u64, 10'u64) == 10'u64
    check toDeviceSince("bad", 7'u64, 10'u64) == 7'u64
    let toDeviceExt = toDevicePayload(11'u64, [%*{"type": "m.dummy"}])
    check toDeviceExt["next_batch"].getStr == "11"
    check optionalToDevicePayload(11'u64, []).kind == JNull

    var oneTimeKeys = initTable[string, int]()
    oneTimeKeys["signed_curve25519"] = 1
    let e2eeExt = e2eePayload(
      changed = ["@alice:localhost"],
      left = ["@bob:localhost"],
      oneTimeKeyCounts = oneTimeKeys,
      unusedFallbackKeyTypes = ["signed_curve25519"]
    )
    check e2eeExt["device_lists"]["changed"][0].getStr == "@alice:localhost"
    check e2eeExt["device_one_time_keys_count"]["signed_curve25519"].getInt == 1

    let combined = extensionsPayload(allExtensionsEnabled(), account, receiptExt, typingExt, toDeviceExt, e2eeExt)
    check combined["account_data"]["rooms"].hasKey("!dm:localhost")
    check combined["to_device"]["events"][0]["type"].getStr == "m.dummy"
    check combined["e2ee"]["device_unused_fallback_key_types"][0].getStr == "signed_curve25519"

  test "v3 sync response keeps legacy /sync rooms and event buckets":
    let timelineEvents = @[%*{"type": "m.room.message", "content": {"body": "hello"}}]
    let stateEvents = @[%*{"type": "m.room.name", "content": {"name": "Direct chat"}}]
    let accountEvents = @[%*{"type": "m.tag", "content": {"tags": {}}}]
    let ephemeralEvents = @[%*{"type": "m.typing", "content": {"user_ids": ["@alice:localhost"]}}]

    var joined = newJObject()
    joined["!dm:localhost"] = joinedRoomPayload(
      timeline = timelineEvents,
      state = stateEvents,
      accountData = accountEvents,
      ephemeral = ephemeralEvents,
      prevBatch = "s0",
      limited = true,
      highlightCount = 1,
      notificationCount = 2
    )

    let response = syncV3Response(
      "s1",
      joinedRooms = joined,
      accountData = accountEvents,
      toDevice = @[%*{"type": "m.dummy"}],
      deviceOneTimeKeysCount = %*{"signed_curve25519": 1},
      deviceUnusedFallbackKeyTypes = ["signed_curve25519"]
    )
    check response["next_batch"].getStr == "s1"
    check response["rooms"]["join"]["!dm:localhost"]["timeline"]["limited"].getBool
    check response["rooms"]["join"]["!dm:localhost"]["timeline"]["prev_batch"].getStr == "s0"
    check response["account_data"]["events"][0]["type"].getStr == "m.tag"
    check response["to_device"]["events"][0]["type"].getStr == "m.dummy"
    check response["device_one_time_keys_count"]["signed_curve25519"].getInt == 1
