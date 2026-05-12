import std/[json, unittest]

import service/presence/aggregate as presence_aggregate
import service/presence/data as presence_data
import "service/presence/mod" as presence_service
import service/presence/pipeline as presence_pipeline
import service/presence/presence as presence_model

suite "Service presence parity":
  test "aggregator ranks states and keeps latest non-empty status":
    var aggregator = presence_aggregate.initPresenceAggregator()
    let userId = "@alice:example.test"

    presence_aggregate.update(
      aggregator,
      userId,
      presence_aggregate.deviceKey("DEVICE_A"),
      presence_aggregate.PresenceUnavailable,
      currentlyActive = false,
      lastActiveAgo = 50'u64,
      statusMsg = presence_aggregate.setStatusMsg("away"),
      nowMs = 1_000'u64,
    )
    presence_aggregate.update(
      aggregator,
      userId,
      presence_aggregate.deviceKey("DEVICE_B"),
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 10'u64,
      statusMsg = presence_aggregate.setStatusMsg("online"),
      nowMs = 1_010'u64,
    )

    let aggregated = presence_aggregate.aggregate(aggregator, userId, 1_010'u64, 100'u64, 300'u64)
    check aggregated.state == presence_aggregate.PresenceOnline
    check aggregated.currentlyActive
    check aggregated.hasStatusMsg
    check aggregated.statusMsg == "online"
    check aggregated.deviceCount == 2

  test "aggregator degrades idle devices and clears or preserves status explicitly":
    var aggregator = presence_aggregate.initPresenceAggregator()
    let userId = "@bob:example.test"
    let device = presence_aggregate.deviceKey("DEVICE")

    presence_aggregate.update(
      aggregator,
      userId,
      device,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 500'u64,
      statusMsg = presence_aggregate.unchangedStatusMsg(),
      nowMs = 10_000'u64,
    )
    check presence_aggregate.aggregate(aggregator, userId, 10_500'u64, 100'u64, 1_000'u64).state ==
      presence_aggregate.PresenceUnavailable

    presence_aggregate.update(
      aggregator,
      userId,
      device,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 0'u64,
      statusMsg = presence_aggregate.setStatusMsg("busy"),
      nowMs = 11_000'u64,
    )
    check presence_aggregate.aggregate(aggregator, userId, 11_000'u64, 100'u64, 1_000'u64).statusMsg == "busy"

    presence_aggregate.update(
      aggregator,
      userId,
      device,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 0'u64,
      statusMsg = presence_aggregate.unchangedStatusMsg(),
      nowMs = 11_001'u64,
    )
    check presence_aggregate.aggregate(aggregator, userId, 11_001'u64, 100'u64, 1_000'u64).statusMsg == "busy"

    presence_aggregate.update(
      aggregator,
      userId,
      device,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 0'u64,
      statusMsg = presence_aggregate.clearStatusMsg(),
      nowMs = 11_002'u64,
    )
    check not presence_aggregate.aggregate(aggregator, userId, 11_002'u64, 100'u64, 1_000'u64).hasStatusMsg

  test "aggregator prunes stale devices to offline":
    var aggregator = presence_aggregate.initPresenceAggregator()
    let userId = "@carol:example.test"
    presence_aggregate.update(
      aggregator,
      userId,
      presence_aggregate.deviceKey("STALE"),
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 10'u64,
      statusMsg = presence_aggregate.unchangedStatusMsg(),
      nowMs = 0'u64,
    )
    let aggregated = presence_aggregate.aggregate(aggregator, userId, 1_000'u64, 100'u64, 100'u64)
    check aggregated.deviceCount == 0
    check aggregated.state == presence_aggregate.PresenceOffline

  test "presence data stores latest event, skips stale refreshes and emits deltas":
    var data = presence_data.initPresenceData()
    let userId = "@alice:example.test"

    let first = presence_data.setPresence(
      data,
      userId,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 0'u64,
      nowMs = 1_000'u64,
    )
    check first.ok
    check first.stored
    check first.count == 1'u64

    let stale = presence_data.setPresence(
      data,
      userId,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      lastActiveAgo = 100'u64,
      nowMs = 1_050'u64,
    )
    check stale.ok
    check not stale.stored

    let status = presence_data.setPresence(
      data,
      userId,
      presence_aggregate.PresenceOnline,
      currentlyActive = true,
      statusMsg = "back",
      hasStatusMsg = true,
      nowMs = 1_100'u64,
    )
    check status.stored
    check status.count == 2'u64

    let fetched = presence_data.getPresence(data, userId, 1_150'u64)
    check fetched.ok
    check fetched.event["content"]["presence"].getStr == presence_aggregate.PresenceOnline
    check fetched.event["content"]["status_msg"].getStr == "back"
    check fetched.event["content"]["last_active_ago"].getInt == 50

    let deltas = presence_data.presenceSince(data, 0'u64)
    check deltas.len == 1
    check deltas[0].count == 2'u64

  test "presence model, service facade and pipeline helpers preserve contracts":
    let presence = presence_model.newPresence(
      presence_aggregate.PresenceOnline,
      true,
      1_000'u64,
      "working",
      hasStatusMsg = true,
    )
    let event = presence_model.toPresenceEvent(presence, "@alice:example.test", 1_250'u64)
    check event["content"]["last_active_ago"].getInt == 250
    check presence_model.fromJson(presence_model.toJson(presence)).ok

    var service = presence_service.initPresenceService(idleTimeoutMs = 100'u64, offlineTimeoutMs = 300'u64)
    presence_service.noteSync(service, "@alice:example.test", 1_000'u64)
    check presence_service.lastSyncGapMs(service, "@alice:example.test", 1_250'u64).gap == 250'u64
    check presence_service.setPresenceForDevice(
      service,
      "@alice:example.test",
      "DEVICE",
      presence_aggregate.PresenceOnline,
      statusMsg = "online",
      hasStatusMsg = true,
      nowMs = 1_300'u64,
    ).stored
    check presence_service.getPresence(service, "@alice:example.test", 1_300'u64).event["content"]["status_msg"].getStr == "online"

    check presence_pipeline.refreshSkipDecision(20'u64, true, 10'u64, true, 5'u64).skip
    check not presence_pipeline.refreshSkipDecision(5'u64, true, 10'u64, true, 5'u64).skip
    check presence_pipeline.timerIsStale(2'u64, 3'u64)
    check not presence_pipeline.timerIsStale(2'u64, 2'u64)
    check presence_pipeline.timeoutForState(presence_aggregate.PresenceOnline, 100'u64, 300'u64) == 100'u64
