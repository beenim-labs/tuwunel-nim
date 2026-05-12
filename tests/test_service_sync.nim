import std/[options, tables, unittest]

import "service/sync/mod" as sync_service
import service/sync/watch as sync_watch

suite "Service sync parity":
  test "connection service stores, loads, lists, drops and clears keys":
    var service = sync_service.initSyncService()
    let aliceMain = sync_service.intoConnectionKey("@alice:example.test", "ALICE1", "main")
    let aliceAux = sync_service.intoConnectionKey("@alice:example.test", "ALICE2", "aux")
    let bobMain = sync_service.intoConnectionKey("@bob:example.test", "BOB1", "main")

    var conn = sync_service.initConnection(globalsince = 3'u64, nextBatch = 4'u64)
    sync_service.store(service, aliceMain, conn)
    check sync_service.isConnectionLoaded(service, aliceMain)
    check sync_service.isConnectionStored(service, aliceMain)

    conn.nextBatch = 5'u64
    sync_service.store(service, aliceAux, conn)
    sync_service.store(service, bobMain, sync_service.initConnection(nextBatch = 9'u64))

    let loaded = sync_service.loadConnection(service, aliceAux)
    check loaded.ok
    check loaded.conn.nextBatch == 5'u64
    check sync_service.listLoadedConnections(service).len == 3

    sync_service.dropConnection(service, bobMain)
    check not sync_service.isConnectionLoaded(service, bobMain)
    check sync_service.clearConnections(service, userId = some("@alice:example.test"), deviceId = some("ALICE2")) == 1
    check sync_service.listStoredConnections(service).len == 1
    check sync_service.listStoredConnections(service)[0].connId == "main"

    check sync_service.clearConnections(service) == 1
    check sync_service.listLoadedConnections(service).len == 0

  test "connection room cursors follow prologue and epilogue semantics":
    var conn = sync_service.initConnection(nextBatch = 30'u64)
    conn.rooms["!old:example.test"] = sync_service.Room(roomsince: 50'u64)
    conn.rooms["!unchanged:example.test"] = sync_service.Room(roomsince: 10'u64)

    sync_service.updateRoomsPrologue(conn, some(20'u64))
    check conn.rooms["!old:example.test"].roomsince == 20'u64
    check conn.rooms["!unchanged:example.test"].roomsince == 10'u64

    sync_service.updateRoomsEpilogue(conn, ["!old:example.test", "!new:example.test"])
    check conn.rooms["!old:example.test"].roomsince == 30'u64
    check conn.rooms["!new:example.test"].roomsince == 30'u64

  test "sliding sync request cache keeps sticky fields and replaces subscriptions":
    var conn = sync_service.initConnection()
    var initialFilter = sync_service.listFilters()
    initialFilter.isDm = some(true)
    initialFilter.tags = @["m.favourite"]

    var first = sync_service.initSyncUpdateRequest()
    first.lists["main"] = sync_service.SyncListConfig(
      filters: some(initialFilter),
      ranges: @[(0, 9)],
      roomDetails: sync_service.RoomDetailConfig(
        timelineLimit: 20,
        requiredState: @[("m.room.name", "")]
      )
    )
    first.extensions.accountData.enabled = some(true)
    first.extensions.accountData.rooms = @["!room:example.test"]
    first.extensions.toDevice.since = "s5"
    first.roomSubscriptions["!room:example.test"] = sync_service.RoomDetailConfig(timelineLimit: 10)
    sync_service.updateCache(conn, first)

    check conn.lists["main"].filters.get().isDm.get()
    check conn.lists["main"].filters.get().tags == @["m.favourite"]
    check conn.lists["main"].roomDetails.timelineLimit == 20
    check conn.extensions.accountData.enabled.get()
    check conn.extensions.toDevice.since == "s5"
    check conn.subscriptions.len == 1

    var secondFilter = sync_service.listFilters()
    secondFilter.isEncrypted = some(true)
    secondFilter.notTags = @["m.lowpriority"]
    var second = sync_service.initSyncUpdateRequest()
    second.lists["main"] = sync_service.SyncListConfig(
      filters: some(secondFilter),
      ranges: @[],
      roomDetails: sync_service.RoomDetailConfig()
    )
    second.extensions.accountData.enabled = none(bool)
    second.extensions.accountData.lists = @["main"]
    second.extensions.toDevice.since = ""
    second.roomSubscriptions["!other:example.test"] = sync_service.RoomDetailConfig(timelineLimit: 5)
    sync_service.updateCache(conn, second)

    let cachedFilter = conn.lists["main"].filters.get()
    check cachedFilter.isDm.get()
    check cachedFilter.isEncrypted.get()
    check cachedFilter.tags == @["m.favourite"]
    check cachedFilter.notTags == @["m.lowpriority"]
    check conn.lists["main"].ranges == @[(0, 9)]
    check conn.lists["main"].roomDetails.requiredState == @[("m.room.name", "")]
    check conn.extensions.accountData.enabled.get()
    check conn.extensions.accountData.rooms == @["!room:example.test"]
    check conn.extensions.accountData.lists == @["main"]
    check conn.extensions.toDevice.since == ""
    check conn.subscriptions.len == 1
    check conn.subscriptions.hasKey("!other:example.test")

  test "watch registers user, device, room and shutdown targets before waiting":
    var shortIds = initTable[string, string]()
    shortIds["!room:example.test"] = "42"

    let watch = sync_watch.registerSyncWatch(
      "@alice:example.test",
      "ALICE1",
      ["!room:example.test"],
      shortIds,
    )

    check watch.targets.len == sync_watch.UserWatchMaps.len + 1 + sync_watch.RoomWatchMaps.len + 1
    check sync_watch.hasTarget(watch, "todeviceid_events", "@alice:example.test\0ALICE1")
    check sync_watch.hasTarget(watch, "pduid_pdu", "42")
    check sync_watch.hasTarget(watch, "typing", "!room:example.test", sync_watch.wkTyping)
    check sync_watch.hasTarget(watch, "server", "shutdown", sync_watch.wkShutdown)

    let match = sync_watch.firstMatchingTarget(watch, "readreceiptid_readreceipt", "!room:example.test\0$event")
    check match.ok
    check match.target.mapName == "readreceiptid_readreceipt"
