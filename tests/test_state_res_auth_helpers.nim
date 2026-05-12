import std/[json, options, sets, tables, unittest]

import core/crypto/ed25519
import core/matrix/server_signing
import core/matrix/event/state_key
import core/matrix/state_res/event_auth
import core/matrix/state_res/event_format as state_event_format
import core/matrix/state_res/events
import core/matrix/state_res/events/[
  create,
  member,
  power_levels,
  third_party_invite,
]
import core/matrix/state_res/fetch_state as state_fetch
import core/matrix/state_res/resolve
import core/matrix/state_res/rules

proc containsAuth(values: openArray[TypeStateKey]; eventType, stateKeyValue: string): bool =
  for value in values:
    if value == typeStateKey(eventType, stateKeyValue):
      return true
  false

proc baseMemberAuthEvents(): Table[EventId, JsonNode] =
  result = initTable[EventId, JsonNode]()
  result["$create"] = %*{
    "event_id": "$create",
    "type": "m.room.create",
    "sender": "@creator:localhost",
    "state_key": "",
    "content": {
      "creator": "@creator:localhost",
      "m.federate": true
    }
  }
  result["$power"] = %*{
    "event_id": "$power",
    "type": "m.room.power_levels",
    "sender": "@creator:localhost",
    "state_key": "",
    "content": {
      "invite": 50,
      "kick": 50,
      "ban": 50,
      "users": {
        "@creator:localhost": 100,
        "@mod:localhost": 60,
        "@weak:localhost": 10
      }
    }
  }
  result["$join-rules-public"] = %*{
    "event_id": "$join-rules-public",
    "type": "m.room.join_rules",
    "state_key": "",
    "content": {"join_rule": "public"}
  }
  result["$join-rules-invite"] = %*{
    "event_id": "$join-rules-invite",
    "type": "m.room.join_rules",
    "state_key": "",
    "content": {"join_rule": "invite"}
  }
  result["$join-rules-restricted"] = %*{
    "event_id": "$join-rules-restricted",
    "type": "m.room.join_rules",
    "state_key": "",
    "content": {"join_rule": "restricted"}
  }
  result["$join-rules-knock"] = %*{
    "event_id": "$join-rules-knock",
    "type": "m.room.join_rules",
    "state_key": "",
    "content": {"join_rule": "knock"}
  }
  result["$creator-member"] = %*{
    "event_id": "$creator-member",
    "type": "m.room.member",
    "sender": "@creator:localhost",
    "state_key": "@creator:localhost",
    "content": {"membership": "join"}
  }
  result["$mod-member"] = %*{
    "event_id": "$mod-member",
    "type": "m.room.member",
    "sender": "@mod:localhost",
    "state_key": "@mod:localhost",
    "content": {"membership": "join"}
  }
  result["$weak-member"] = %*{
    "event_id": "$weak-member",
    "type": "m.room.member",
    "sender": "@weak:localhost",
    "state_key": "@weak:localhost",
    "content": {"membership": "join"}
  }
  result["$invited-member"] = %*{
    "event_id": "$invited-member",
    "type": "m.room.member",
    "sender": "@creator:localhost",
    "state_key": "@invited:localhost",
    "content": {"membership": "invite"}
  }
  result["$banned-member"] = %*{
    "event_id": "$banned-member",
    "type": "m.room.member",
    "sender": "@mod:localhost",
    "state_key": "@banned:localhost",
    "content": {"membership": "ban"}
  }
  result["$third-party"] = %*{
    "event_id": "$third-party",
    "type": "m.room.third_party_invite",
    "sender": "@creator:localhost",
    "state_key": "token",
    "content": {"public_key": "key"}
  }

proc fixedSeed(): seq[byte] =
  result = newSeq[byte](Ed25519PrivateSeedLen)
  for idx in 0 ..< result.len:
    result[idx] = byte(idx)

proc memberAuthState(
  eventsById: Table[EventId, JsonNode];
  joinRules = "$join-rules-public";
  extra: openArray[tuple[key: TypeStateKey, eventId: EventId]] = []
): FetchState =
  var entries = @[
    (typeStateKey("m.room.create", ""), "$create"),
    (typeStateKey("m.room.power_levels", ""), "$power"),
    (typeStateKey("m.room.join_rules", ""), joinRules),
    (typeStateKey("m.room.member", "@creator:localhost"), "$creator-member"),
    (typeStateKey("m.room.member", "@mod:localhost"), "$mod-member"),
    (typeStateKey("m.room.member", "@weak:localhost"), "$weak-member"),
    (typeStateKey("m.room.member", "@invited:localhost"), "$invited-member"),
    (typeStateKey("m.room.member", "@banned:localhost"), "$banned-member"),
    (typeStateKey("m.room.third_party_invite", "token"), "$third-party"),
  ]
  for entry in extra:
    entries.add(entry)
  state_fetch.fetchState(stateMap(entries), eventsById)

suite "State resolution event auth helpers":
  test "room create helpers preserve Rust defaults and room-version rules":
    let event = roomCreateEvent(%*{
      "type": "m.room.create",
      "sender": "@creator:localhost",
      "state_key": "",
      "content": {
        "m.federate": false,
        "creator": "@legacy:localhost",
        "additional_creators": [
          "@zara:localhost",
          "@alice:localhost",
          "@alice:localhost"
        ]
      }
    })

    check event.roomVersion().value == "1"
    check event.federate().ok
    check not event.federate().value
    check event.creator(authorizationRules("10")).value == "@legacy:localhost"
    check event.creator(authorizationRules("11")).value == "@creator:localhost"
    check event.additionalCreators(authorizationRules("11")).values.len == 0
    check event.additionalCreators(authorizationRules("12")).values == @[
      "@alice:localhost",
      "@zara:localhost",
    ]
    check event.creators(authorizationRules("12")).values == @[
      "@creator:localhost",
      "@alice:localhost",
      "@zara:localhost",
    ]
    check event.hasCreator().value

  test "member content and third-party invite accessors validate Matrix fields":
    let content = roomMemberEventContent(%*{
      "membership": "invite",
      "third_party_invite": {
        "signed": {
          "mxid": "@bob:localhost",
          "token": "invite-token",
          "signatures": {"localhost": {"ed25519:key": "sig"}}
        }
      }
    })

    let membership = content.membership()
    check membership.ok
    check membership.state == msInvite
    check membership.value == "invite"

    let invite = content.thirdPartyInvite()
    check invite.ok
    check invite.invite.isSome
    check invite.invite.get().token().value == "invite-token"
    check invite.invite.get().mxid().value == "@bob:localhost"
    check invite.invite.get().signatures().ok
    check invite.invite.get().signedCanonicalJson().ok

    let thirdParty = roomThirdPartyInviteEvent(%*{
      "type": "m.room.third_party_invite",
      "state_key": "invite-token",
      "content": {
        "public_key": "b",
        "public_keys": [
          {"public_key": "a"},
          {"public_key": "b"}
        ]
      }
    })
    check thirdParty.publicKeys().keys == @["a", "b"]

  test "auth type selection matches Rust member invite and restricted join logic":
    let invite = %*{
      "type": "m.room.member",
      "sender": "@alice:localhost",
      "state_key": "@bob:localhost",
      "content": {
        "membership": "invite",
        "third_party_invite": {
          "signed": {
            "token": "invite-token",
            "mxid": "@bob:localhost",
            "signatures": {}
          }
        }
      }
    }
    let inviteAuth = authTypesForEvent(invite, authorizationRules("11"))
    check inviteAuth.ok
    check inviteAuth.authTypes == @[
      typeStateKey("m.room.create", ""),
      typeStateKey("m.room.power_levels", ""),
      typeStateKey("m.room.member", "@alice:localhost"),
      typeStateKey("m.room.member", "@bob:localhost"),
      typeStateKey("m.room.join_rules", ""),
      typeStateKey("m.room.third_party_invite", "invite-token"),
    ]

    let join = %*{
      "type": "m.room.member",
      "sender": "@bob:localhost",
      "state_key": "@bob:localhost",
      "content": {
        "membership": "join",
        "join_authorised_via_users_server": "@alice:localhost"
      }
    }
    let restrictedJoin = authTypesForEvent(join, authorizationRules("11"))
    check restrictedJoin.ok
    check restrictedJoin.authTypes.containsAuth("m.room.member", "@alice:localhost")

    let preRestrictedJoin = authTypesForEvent(join, authorizationRules("7"))
    check preRestrictedJoin.ok
    check not preRestrictedJoin.authTypes.containsAuth("m.room.member", "@alice:localhost")

    let roomV12Message = authTypesForEvent(
      "m.room.message",
      "@alice:localhost",
      none(string),
      %*{"body": "hello"},
      authorizationRules("12"),
    )
    check roomV12Message.ok
    check not roomV12Message.authTypes.containsAuth("m.room.create", "")
    check authTypesForEvent(invite, authorizationRules("11"), alwaysCreate = true).ok

  test "state-independent auth checker reports missing duplicate and unexpected auth events":
    let event = %*{
      "type": "m.room.message",
      "sender": "@alice:localhost",
      "content": {"body": "hello"}
    }
    let authEvents = [
      %*{"type": "m.room.create", "state_key": "", "content": {}},
      %*{"type": "m.room.power_levels", "state_key": "", "content": {}},
      %*{"type": "m.room.member", "state_key": "@alice:localhost", "content": {"membership": "join"}}
    ]
    check checkStateIndependentAuthTypes(event, authEvents, authorizationRules("11")).ok

    let noisyAuthEvents = [
      %*{"type": "m.room.create", "state_key": "", "content": {}},
      %*{"type": "m.room.create", "state_key": "", "content": {}},
      %*{"type": "m.room.name", "state_key": "", "content": {}}
    ]
    let checked = checkStateIndependentAuthTypes(event, noisyAuthEvents, authorizationRules("11"))
    check not checked.ok
    check checked.duplicate.containsAuth("m.room.create", "")
    check checked.missing.containsAuth("m.room.power_levels", "")
    check checked.unexpected.containsAuth("m.room.name", "")

  test "power level helpers implement Rust defaults map parsing and creator fallback":
    let event = roomPowerLevelsEvent(%*{
      "type": "m.room.power_levels",
      "state_key": "",
      "content": {
        "users_default": "5",
        "state_default": "60",
        "users": {"@alice:localhost": "75"},
        "events": {"m.room.message": "25"}
      }
    })
    let rulesV10 = authorizationRules("10")
    check event.getAsIntOrDefault(plKick, rulesV10).value == 50
    check event.userPowerLevel("@alice:localhost", rulesV10).value == 75
    check event.userPowerLevel("@bob:localhost", rulesV10).value == 5
    check event.eventPowerLevel("m.room.message", none(string), rulesV10).value == 25
    check event.eventPowerLevel("m.room.topic", some(""), rulesV10).value == 60
    check event.intFieldsMap(rulesV10).values.len == 2
    check not event.getAsIntOrDefault(plUsersDefault, authorizationRules("12")).ok

    let absentPowerLevels = none(RoomPowerLevelsEvent)
    check absentPowerLevels.userPowerLevel(
      "@creator:localhost",
      ["@creator:localhost"],
      authorizationRules("10"),
    ).value == DefaultCreatorPowerLevel
    check absentPowerLevels.userPowerLevel(
      "@creator:localhost",
      ["@creator:localhost"],
      authorizationRules("12"),
    ).infinite

  test "power event detection follows Matrix state-res definition":
    check isPowerEvent(%*{
      "type": "m.room.power_levels",
      "state_key": "",
      "content": {}
    })
    check isPowerEvent(%*{
      "type": "m.room.member",
      "sender": "@alice:localhost",
      "state_key": "@bob:localhost",
      "content": {"membership": "ban"}
    })
    check not isPowerEvent(%*{
      "type": "m.room.member",
      "sender": "@alice:localhost",
      "state_key": "@alice:localhost",
      "content": {"membership": "ban"}
    })
    check not isPowerEvent(%*{
      "type": "m.room.message",
      "content": {"body": "hello"}
    })

  test "resolve helpers split conflicts and compute auth difference":
    let nameKey = typeStateKey("m.room.name", "")
    let powerKey = typeStateKey("m.room.power_levels", "")
    let topicKey = typeStateKey("m.room.topic", "")
    let split = splitConflictedState([
      stateMap([(nameKey, "$name-a"), (powerKey, "$power"), (topicKey, "$topic")]),
      stateMap([(nameKey, "$name-b"), (powerKey, "$power")]),
      stateMap([(nameKey, "$name-a"), (powerKey, "$power")]),
    ])

    check split.unconflicted[powerKey] == "$power"
    check not split.unconflicted.hasKey(nameKey)
    check split.conflicted[nameKey] == @["$name-a", "$name-b"]
    check split.conflicted[topicKey] == @["$topic"]
    check authDifference([
      authSet(["$a", "$b", "$b"]),
      authSet(["$b", "$c"]),
      authSet(["$b", "$c"]),
    ]) == @["$a", "$c"]

  test "reverse topological power ordering uses power timestamp and event id ties":
    let graph = eventGraph([
      ("$old", @[]),
      ("$high", @["$old"]),
      ("$low", @["$old"]),
      ("$same-a", @["$high"]),
      ("$same-b", @["$high"]),
    ])
    var info = initTable[EventId, TieBreakerInfo]()
    info["$old"] = TieBreakerInfo(powerLevel: 0, originServerTs: 10)
    info["$high"] = TieBreakerInfo(powerLevel: 100, originServerTs: 30)
    info["$low"] = TieBreakerInfo(powerLevel: 50, originServerTs: 20)
    info["$same-a"] = TieBreakerInfo(powerLevel: 0, originServerTs: 50)
    info["$same-b"] = TieBreakerInfo(powerLevel: 0, originServerTs: 50)

    let sorted = topologicalSort(graph, info)
    check sorted.ok
    check sorted.eventIds == @["$old", "$high", "$low", "$same-a", "$same-b"]

    let missingReference = eventGraph([("$new", @["$missing"])])
    check not topologicalSort(missingReference, info).ok

    let cycle = eventGraph([("$a", @["$b"]), ("$b", @["$a"])])
    info["$a"] = TieBreakerInfo(powerLevel: 0, originServerTs: 1)
    info["$b"] = TieBreakerInfo(powerLevel: 0, originServerTs: 2)
    check not topologicalSort(cycle, info).ok

  test "conflicted subgraph and full conflicted set include auth paths between conflicts":
    let authGraph = eventGraph([
      ("$a", @["$x"]),
      ("$x", @["$b"]),
      ("$b", @[]),
      ("$isolated", @[]),
    ])
    check conflictedSubgraphDfs(["$a", "$b"], authGraph) == @["$a", "$b", "$x"]

    var conflicts = initOrderedTable[TypeStateKey, seq[EventId]]()
    conflicts[typeStateKey("m.room.name", "")] = @["$a"]
    conflicts[typeStateKey("m.room.topic", "")] = @["$isolated"]
    var existing = initHashSet[EventId]()
    for eventId in ["$a", "$b", "$c", "$x"]:
      existing.incl(eventId)

    check fullConflictedSet(
      conflicts,
      [authSet(["$b", "$c"]), authSet(["$c"])],
      existing,
      authGraph,
      considerConflictedSubgraph = true,
    ) == @["$a", "$b", "$x"]

  test "event format and fetch-state helpers expose typed current-state lookups":
    let memberEvent = %*{
      "event_id": "$member",
      "type": "m.room.member",
      "sender": "@alice:localhost",
      "state_key": "@alice:localhost",
      "origin_server_ts": 1234,
      "auth_events": ["$create", ["$power", {}]],
      "prev_events": [["$prev", {}]],
      "content": {"membership": "join"}
    }
    let key = state_event_format.typeStateKey(memberEvent)
    check key.ok
    check key.key == typeStateKey("m.room.member", "@alice:localhost")
    check state_event_format.eventId(memberEvent) == "$member"
    check state_event_format.sender(memberEvent) == "@alice:localhost"
    check state_event_format.originServerTs(memberEvent) == 1234
    check state_event_format.authEvents(memberEvent) == @["$create", "$power"]
    check state_event_format.prevEvents(memberEvent) == @["$prev"]

    var eventsById = initTable[EventId, JsonNode]()
    eventsById["$create"] = %*{
      "event_id": "$create",
      "type": "m.room.create",
      "sender": "@alice:localhost",
      "state_key": "",
      "content": {"room_version": "11"}
    }
    eventsById["$member"] = memberEvent
    eventsById["$power"] = %*{
      "event_id": "$power",
      "type": "m.room.power_levels",
      "state_key": "",
      "content": {"users": {"@alice:localhost": 100}}
    }
    eventsById["$join"] = %*{
      "event_id": "$join",
      "type": "m.room.join_rules",
      "state_key": "",
      "content": {"join_rule": "invite"}
    }
    eventsById["$third"] = %*{
      "event_id": "$third",
      "type": "m.room.third_party_invite",
      "state_key": "token",
      "content": {"public_key": "key"}
    }

    let currentState = stateMap([
      (typeStateKey("m.room.create", ""), "$create"),
      (typeStateKey("m.room.member", "@alice:localhost"), "$member"),
      (typeStateKey("m.room.power_levels", ""), "$power"),
      (typeStateKey("m.room.join_rules", ""), "$join"),
      (typeStateKey("m.room.third_party_invite", "token"), "$third"),
    ])
    let fetch = state_fetch.fetchState(currentState, eventsById)
    check fetch.roomCreateEvent().ok
    check fetch.roomCreateEvent().event.creator(authorizationRules("11")).value == "@alice:localhost"
    check fetch.userMembership("@alice:localhost").state == msJoin
    check fetch.userMembership("@missing:localhost").state == msLeave
    check fetch.roomPowerLevelsEvent().isSome
    check $fetch.joinRule().rule == "invite"
    check fetch.roomThirdPartyInviteEvent("token").isSome
    check fetch.roomThirdPartyInviteEvent("missing").isNone

  test "mainline power sort and iterative auth-check helpers order and apply events":
    var eventsById = initTable[EventId, JsonNode]()
    eventsById["$create"] = %*{
      "event_id": "$create",
      "type": "m.room.create",
      "sender": "@alice:localhost",
      "state_key": "",
      "origin_server_ts": 1,
      "content": {"room_version": "11"}
    }
    eventsById["$power-old"] = %*{
      "event_id": "$power-old",
      "type": "m.room.power_levels",
      "sender": "@alice:localhost",
      "state_key": "",
      "origin_server_ts": 2,
      "auth_events": ["$create"],
      "content": {"users": {"@alice:localhost": 100}}
    }
    eventsById["$power-new"] = %*{
      "event_id": "$power-new",
      "type": "m.room.power_levels",
      "sender": "@alice:localhost",
      "state_key": "",
      "origin_server_ts": 3,
      "auth_events": ["$power-old"],
      "content": {"users": {"@alice:localhost": 100}}
    }
    eventsById["$early"] = %*{
      "event_id": "$early",
      "type": "m.room.message",
      "sender": "@alice:localhost",
      "origin_server_ts": 9,
      "auth_events": [],
      "content": {"body": "early"}
    }
    eventsById["$old-rooted"] = %*{
      "event_id": "$old-rooted",
      "type": "m.room.message",
      "sender": "@alice:localhost",
      "origin_server_ts": 10,
      "auth_events": ["$power-old"],
      "content": {"body": "old"}
    }
    eventsById["$new-rooted"] = %*{
      "event_id": "$new-rooted",
      "type": "m.room.message",
      "sender": "@alice:localhost",
      "origin_server_ts": 8,
      "auth_events": ["$power-new"],
      "content": {"body": "new"}
    }

    let mainline = mainlineSort(
      some("$power-new"),
      ["$new-rooted", "$old-rooted", "$early"],
      eventsById,
    )
    check mainline.ok
    check mainline.eventIds == @["$early", "$old-rooted", "$new-rooted"]

    eventsById["$ban"] = %*{
      "event_id": "$ban",
      "type": "m.room.member",
      "sender": "@alice:localhost",
      "state_key": "@bob:localhost",
      "origin_server_ts": 4,
      "auth_events": ["$create", "$power-old"],
      "content": {"membership": "ban"}
    }
    let powerOrdered = powerSort(
      authorizationRules("11"),
      ["$ban", "$create", "$power-old"],
      eventsById,
    )
    check powerOrdered.ok
    check powerOrdered.eventIds == @["$create", "$power-old", "$ban"]

    eventsById["$member"] = %*{
      "event_id": "$member",
      "type": "m.room.member",
      "sender": "@alice:localhost",
      "state_key": "@alice:localhost",
      "origin_server_ts": 5,
      "content": {"membership": "join"}
    }
    eventsById["$topic"] = %*{
      "event_id": "$topic",
      "type": "m.room.topic",
      "sender": "@alice:localhost",
      "state_key": "",
      "origin_server_ts": 6,
      "auth_events": ["$create", "$power-old", "$member"],
      "content": {"topic": "Nim"}
    }
    eventsById["$bad-topic"] = %*{
      "event_id": "$bad-topic",
      "type": "m.room.topic",
      "sender": "@alice:localhost",
      "state_key": "",
      "origin_server_ts": 7,
      "auth_events": ["$create"],
      "content": {"topic": "bad"}
    }
    let initial = stateMap([
      (typeStateKey("m.room.create", ""), "$create"),
      (typeStateKey("m.room.power_levels", ""), "$power-old"),
      (typeStateKey("m.room.member", "@alice:localhost"), "$member"),
    ])
    let checked = iterativeAuthCheck(["$topic", "$bad-topic"], initial, eventsById, authorizationRules("11"))
    check checked.ok
    check checked.state[typeStateKey("m.room.topic", "")] == "$topic"
    check checked.rejected == @["$bad-topic"]

  test "room-member auth accepts public and restricted joins and rejects bad joins":
    var eventsById = baseMemberAuthEvents()
    let createEvent = roomCreateEvent(eventsById["$create"])
    let publicFetch = memberAuthState(eventsById)
    let publicJoin = %*{
      "event_id": "$bob-join",
      "type": "m.room.member",
      "sender": "@bob:localhost",
      "state_key": "@bob:localhost",
      "content": {"membership": "join"}
    }
    check checkRoomMember(publicJoin, authorizationRules("11"), createEvent, publicFetch).ok

    var createJoin = publicJoin.copy()
    createJoin["event_id"] = %"$creator-initial-join"
    createJoin["sender"] = %"@creator:localhost"
    createJoin["state_key"] = %"@creator:localhost"
    createJoin["prev_events"] = %["$create"]
    check checkRoomMember(createJoin, authorizationRules("10"), createEvent, publicFetch).ok

    var badSender = publicJoin.copy()
    badSender["sender"] = %"@mallory:localhost"
    check not checkRoomMember(badSender, authorizationRules("11"), createEvent, publicFetch).ok

    let restrictedFetch = memberAuthState(eventsById, "$join-rules-restricted")
    var restrictedJoin = publicJoin.copy()
    restrictedJoin["content"] = %*{
      "membership": "join",
      "join_authorised_via_users_server": "@mod:localhost"
    }
    check checkRoomMember(restrictedJoin, authorizationRules("11"), createEvent, restrictedFetch).ok
    restrictedJoin["content"]["join_authorised_via_users_server"] = %"@weak:localhost"
    check not checkRoomMember(restrictedJoin, authorizationRules("11"), createEvent, restrictedFetch).ok

    var remoteCreate = eventsById["$create"].copy()
    remoteCreate["content"]["m.federate"] = %false
    let remoteTarget = %*{
      "event_id": "$remote",
      "type": "m.room.member",
      "sender": "@bob:remote",
      "state_key": "@bob:remote",
      "content": {"membership": "join"}
    }
    check not checkRoomMember(remoteTarget, authorizationRules("11"), roomCreateEvent(remoteCreate), publicFetch).ok

  test "room-member auth covers invite leave ban knock and third-party invite signatures":
    var eventsById = baseMemberAuthEvents()
    let createEvent = roomCreateEvent(eventsById["$create"])
    let fetch = memberAuthState(eventsById)

    let invite = %*{
      "event_id": "$invite",
      "type": "m.room.member",
      "sender": "@mod:localhost",
      "state_key": "@new:localhost",
      "content": {"membership": "invite"}
    }
    check checkRoomMember(invite, authorizationRules("11"), createEvent, fetch).ok
    var weakInvite = invite.copy()
    weakInvite["sender"] = %"@weak:localhost"
    check not checkRoomMember(weakInvite, authorizationRules("11"), createEvent, fetch).ok

    let selfLeave = %*{
      "event_id": "$leave",
      "type": "m.room.member",
      "sender": "@invited:localhost",
      "state_key": "@invited:localhost",
      "content": {"membership": "leave"}
    }
    check checkRoomMember(selfLeave, authorizationRules("11"), createEvent, fetch).ok

    let kick = %*{
      "event_id": "$kick",
      "type": "m.room.member",
      "sender": "@mod:localhost",
      "state_key": "@weak:localhost",
      "content": {"membership": "leave"}
    }
    check checkRoomMember(kick, authorizationRules("11"), createEvent, fetch).ok

    let ban = %*{
      "event_id": "$ban",
      "type": "m.room.member",
      "sender": "@mod:localhost",
      "state_key": "@weak:localhost",
      "content": {"membership": "ban"}
    }
    check checkRoomMember(ban, authorizationRules("11"), createEvent, fetch).ok
    var weakBan = ban.copy()
    weakBan["sender"] = %"@weak:localhost"
    weakBan["state_key"] = %"@mod:localhost"
    check not checkRoomMember(weakBan, authorizationRules("11"), createEvent, fetch).ok

    let knockFetch = memberAuthState(eventsById, "$join-rules-knock")
    let knock = %*{
      "event_id": "$knock",
      "type": "m.room.member",
      "sender": "@knocker:localhost",
      "state_key": "@knocker:localhost",
      "content": {"membership": "knock"}
    }
    check checkRoomMember(knock, authorizationRules("11"), createEvent, knockFetch).ok
    check not checkRoomMember(knock, authorizationRules("6"), createEvent, knockFetch).ok

    let seed = fixedSeed()
    let publicKey = publicKeyFromSeed(seed)
    check publicKey.ok
    let signedInvite = %*{
      "mxid": "@third:localhost",
      "token": "token"
    }
    let canonical = canonicalSigningString(signedInvite)
    check canonical.ok
    let signature = sign(seed, canonical.value)
    check signature.ok
    signedInvite["signatures"] = %*{
      "localhost": {
        "ed25519:key": encodeUnpaddedBase64(signature.signature)
      }
    }

    eventsById["$third-party"]["content"]["public_key"] = %encodeUnpaddedBase64(publicKey.publicKey)

    let thirdPartyInvite = %*{
      "event_id": "$3pid-invite",
      "type": "m.room.member",
      "sender": "@creator:localhost",
      "state_key": "@third:localhost",
      "content": {
        "membership": "invite",
        "third_party_invite": {"signed": signedInvite}
      }
    }
    let thirdPartyCheck = checkRoomMember(thirdPartyInvite, authorizationRules("11"), createEvent, fetch)
    check thirdPartyCheck.ok

    var tamperedThirdParty = thirdPartyInvite.copy()
    tamperedThirdParty["content"]["third_party_invite"]["signed"]["mxid"] = %"@other:localhost"
    let tamperedCheck = checkRoomMember(tamperedThirdParty, authorizationRules("11"), createEvent, fetch)
    check not tamperedCheck.ok
