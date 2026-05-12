import std/[json, unittest]

import api/client/context as client_context
import api/client/message as client_message
import api/client/redact as client_redact
import api/client/relations as client_relations
import api/client/room/event as client_room_event
import api/client/room/initial_sync as client_initial_sync
import api/client/room/summary as client_room_summary
import api/client/room/upgrade as client_room_upgrade
import api/client/search as client_search
import api/client/send as client_send
import api/client/state as client_state
import api/client/threads as client_threads

suite "Client room timeline, state and send API helpers":
  test "message and context helpers cap limits and preserve response shapes":
    check client_message.messageLimit(0) == client_message.LimitDefault
    check client_message.messageLimit(5000) == client_message.LimitMax
    check client_message.normalizeDirection("").backwards
    check client_message.normalizeDirection("f").ok
    check client_message.normalizeDirection("sideways").errcode == "M_INVALID_PARAM"

    let msg = client_message.messagesResponse(%*[%*{"event_id": "$1"}], start = "s1", ending = "s2")
    check msg["chunk"][0]["event_id"].getStr == "$1"
    check msg["start"].getStr == "s1"
    check msg["end"].getStr == "s2"

    check client_context.contextLimit(500) == client_context.LimitMax
    let ctx = client_context.contextResponse(
      %*{"event_id": "$2"},
      %*[],
      %*[%*{"event_id": "$3"}],
      %*[%*{"type": "m.room.name"}],
      start = "s2",
      ending = "s3",
    )
    check ctx["event"]["event_id"].getStr == "$2"
    check ctx["events_after"][0]["event_id"].getStr == "$3"
    check ctx["state"][0]["type"].getStr == "m.room.name"
    check client_context.contextAccessPolicy(true, false, true).errcode == "M_FORBIDDEN"

  test "send, redact and state helpers return Matrix event id responses and errors":
    check client_send.sendResponse("$evt")["event_id"].getStr == "$evt"
    check client_send.redactsFromSendContent("m.room.redaction", %*{"redacts": "$old"}) == "$old"
    check client_send.sendAccessPolicy(true, true, eventType = "m.room.encrypted", encryptionAllowed = false).message == "Encryption has been disabled"

    let redaction = client_redact.redactionContent(%*{"reason": "cleanup"}, "$old")
    check redaction["redacts"].getStr == "$old"
    check client_redact.redactResponse("$redaction")["event_id"].getStr == "$redaction"
    check client_redact.redactAccessPolicy(true, false).errcode == "M_FORBIDDEN"

    check client_state.stateEventsResponse(%*[%*{"type": "m.room.name"}]).len == 1
    check client_state.stateEventResponse(%*{"name": "Lobby"})["name"].getStr == "Lobby"
    check client_state.sendStateResponse("$state")["event_id"].getStr == "$state"
    check client_state.sendStatePolicy(true, true, "m.room.create").errcode == "M_BAD_JSON"

  test "relations, threads, search, initial sync, summary and upgrade helpers match payload contracts":
    check client_relations.relationsLimit(0) == client_relations.LimitDefault
    let relations = client_relations.relationsResponse(%*[%*{"event_id": "$rel"}], nextBatch = "s2", prevBatch = "s1", recursionDepth = 1)
    check relations["chunk"][0]["event_id"].getStr == "$rel"
    check relations["recursion_depth"].getInt == 1
    check client_relations.relationsPolicy(true, false, true).message == "You cannot view this room."

    check client_threads.threadsLimit(500) == client_threads.LimitMax
    let threads = client_threads.threadsResponse(%*[%*{"event_id": "$root"}], nextBatch = "s9")
    check threads["chunk"][0]["event_id"].getStr == "$root"
    check threads["next_batch"].getStr == "s9"

    check client_search.searchLimit(%*{"limit": 500}) == client_search.LimitMax
    let highlights = client_search.searchHighlights("Needle needle beta")
    check highlights.len == 2
    let searchResult = client_search.roomEventsResponse(1, highlights, %*[%*{"rank": 1}], newJObject(), nextBatch = "1")
    check searchResult["search_categories"]["room_events"]["next_batch"].getStr == "1"

    check client_initial_sync.initialSyncLimit(500) == client_initial_sync.LimitMax
    let initial = client_initial_sync.initialSyncResponse(
      "!room:localhost",
      "join",
      "private",
      client_initial_sync.messagesChunk(%*[], start = "s0", ending = "s1"),
      %*[],
      %*[],
    )
    check initial["room_id"].getStr == "!room:localhost"
    check initial["messages"]["end"].getStr == "s1"

    check client_room_event.roomEventResponse(%*{"event_id": "$event"})["event_id"].getStr == "$event"
    check client_room_summary.summaryResponse(%*{"room_id": "!room:localhost"}, membership = "join")["membership"].getStr == "join"
    check client_room_upgrade.upgradeResponse("!new:localhost")["replacement_room"].getStr == "!new:localhost"
