import std/[options, strutils, tables, unittest]

import "service/sending/mod" as sending_service
import service/sending/[data as sending_data, dest as sending_dest, sender as sending_sender]

suite "Service sending parity":
  test "destination prefixes and stored event parsing match Rust key layout":
    let fed = sending_dest.federationDestination("remote.example")
    let app = sending_dest.appserviceDestination("whatsapp")
    let push = sending_dest.pushDestination("@alice:example.test", "push-key")

    check sending_dest.getPrefix(fed) == "remote.example" & $sending_dest.Separator
    check sending_dest.getPrefix(app) == "+whatsapp" & $sending_dest.Separator
    check sending_dest.getPrefix(push) ==
      "$@alice:example.test" & $sending_dest.Separator & "push-key" & $sending_dest.Separator

    let parsedFed = sending_data.parseServerCurrentEvent(sending_dest.getPrefix(fed) & "$pdu", "")
    check parsedFed.ok
    check parsedFed.dest.kind == sending_dest.dkFederation
    check parsedFed.dest.serverName == "remote.example"
    check parsedFed.event.kind == sending_data.sekPdu
    check parsedFed.event.pduId == "$pdu"

    let parsedEdu = sending_data.parseServerCurrentEvent(sending_dest.getPrefix(app) & "ignored", """{"edu":true}""")
    check parsedEdu.ok
    check parsedEdu.dest.kind == sending_dest.dkAppservice
    check parsedEdu.event.kind == sending_data.sekEdu
    check parsedEdu.event.edu == """{"edu":true}"""

  test "queued requests move to active and cleanup removes destination prefixes":
    var store = sending_data.initSendingData()
    let fed = sending_dest.federationDestination("remote.example")
    let push = sending_dest.pushDestination("@alice:example.test", "push-key")

    let keys = sending_data.queueRequests(store, [
      (event: sending_data.pduEvent("$pdu1"), dest: fed),
      (event: sending_data.eduEvent("""{"type":"m.typing"}"""), dest: fed),
      (event: sending_data.pduEvent("$push"), dest: push),
    ])
    check keys.len == 3
    check keys[0] == sending_dest.getPrefix(fed) & "$pdu1"
    check keys[1].startsWith(sending_dest.getPrefix(fed))
    check store.queued.len == 3

    let fedQueued = sending_data.queuedRequests(store, fed)
    check fedQueued.len == 2
    sending_data.markAsActive(store, fedQueued)
    check store.active.len == 2
    check sending_data.activeRequestsFor(store, fed).len == 2
    check store.queued.len == 1

    check sending_data.deleteAllActiveRequestsFor(store, fed) == 2
    check store.active.len == 0
    check sending_data.deleteAllRequestsFor(store, push) == 1
    check store.queued.len == 0

    sending_data.setLatestEduCount(store, "remote.example", 42'u64)
    check sending_data.getLatestEduCount(store, "remote.example") == 42'u64
    check sending_data.getLatestEduCount(store, "elsewhere.test") == 0'u64

  test "sender selector blocks running destinations and applies federation backoff":
    var selector = sending_sender.initSendingSelector(senderTimeoutSecs = 10'u64, senderRetryBackoffLimitSecs = 100'u64)
    let fed = sending_dest.federationDestination("remote.example")
    let app = sending_dest.appserviceDestination("whatsapp")

    check sending_sender.selectEventsCurrent(selector, fed, 1_000'u64).allow
    check not sending_sender.selectEventsCurrent(selector, fed, 1_001'u64).allow

    sending_sender.markFailed(selector, fed, 2_000'u64)
    let blocked = sending_sender.selectEventsCurrent(selector, fed, 3_000'u64)
    check not blocked.allow
    check not blocked.retry

    let retry = sending_sender.selectEventsCurrent(selector, fed, 13_000'u64)
    check retry.allow
    check retry.retry

    check sending_sender.selectEventsCurrent(selector, app, 20_000'u64).allow
    sending_sender.markFailed(selector, app, 21_000'u64)
    let appRetry = sending_sender.selectEventsCurrent(selector, app, 21_001'u64)
    check appRetry.allow
    check appRetry.retry

  test "selectEvents marks new queue rows active and retries previous active rows":
    var store = sending_data.initSendingData()
    var selector = sending_sender.initSendingSelector(senderTimeoutSecs = 1'u64, senderRetryBackoffLimitSecs = 10'u64)
    let fed = sending_dest.federationDestination("remote.example")
    let keys = sending_data.queueRequests(store, [
      (event: sending_data.pduEvent("$pdu1"), dest: fed)
    ])
    let selected = sending_sender.selectEvents(selector, store, fed, sending_data.queuedRequests(store, fed), 1_000'u64)
    check selected.isSome
    check selected.get().len == 1
    check store.active.hasKey(keys[0])
    check store.queued.len == 0

    sending_sender.markFailed(selector, fed, 2_000'u64)
    let retry = sending_sender.selectEvents(selector, store, fed, [], 4_000'u64)
    check retry.isSome
    check retry.get()[0].pduId == "$pdu1"

    discard sending_sender.finishResponseOk(selector, store, fed)
    check store.active.len == 0
    check selector.statuses.len == 0

  test "service enqueue helpers dispatch, filter local room servers and clean up":
    var service = sending_service.initSendingService(localServerName = "example.test", senderWorkers = 4)
    sending_service.setRoomServers(service, "!room:example.test", ["example.test", "remote.example", "elsewhere.test"])

    let pduKeys = sending_service.sendPduRoom(service, "!room:example.test", "$pdu")
    check pduKeys.len == 2
    check service.dispatches.len == 2
    check service.dispatches[0].queueId.len > 0
    check sending_service.shardId(service, service.dispatches[0].dest) in 0 .. 3

    let eduKey = sending_service.sendEduAppservice(service, "whatsapp", """{"type":"m.receipt"}""")
    check eduKey.startsWith("+whatsapp" & $sending_dest.Separator)
    check service.db.queued.len == 3

    let flushes = sending_service.flushRoom(service, "!room:example.test")
    check flushes == 2
    check service.dispatches[^1].event.kind == sending_data.sekFlush
    check service.dispatches[^1].queueId == ""

    let cleaned = sending_service.cleanupEvents(service, appserviceId = "whatsapp")
    check cleaned.cleaned
    check cleaned.deleted == 1

    let warning = sending_service.cleanupEvents(service, appserviceId = "whatsapp", userId = "@alice:example.test")
    check warning.warning

  test "numSenders clamps requested worker count like Rust service build":
    check sending_service.numSenders(0, 8, 8) == 1
    check sending_service.numSenders(3, 8, 8) == 3
    check sending_service.numSenders(20, 4, 8) == 4
