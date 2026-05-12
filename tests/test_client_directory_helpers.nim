import std/[json, unittest]

import api/client/alias as client_alias
import api/client/directory as client_directory
import api/client/room/aliases as client_room_aliases
import api/client/space as client_space
import api/client/user_directory as client_user_directory

suite "Client directory, alias and discovery API helpers":
  test "alias helpers preserve alias response and canonical alias content mutation":
    let response = client_alias.aliasResponse("!room:localhost", ["localhost", "remote.example"])
    check response["room_id"].getStr == "!room:localhost"
    check response["servers"][0].getStr == "localhost"
    check response["servers"][1].getStr == "remote.example"

    var content = client_alias.aliasContentWith(newJObject(), "#main:localhost")
    check content["alias"].getStr == "#main:localhost"
    content = client_alias.aliasContentWith(content, "#alt:localhost")
    check content["alias"].getStr == "#main:localhost"
    check content["alt_aliases"][0].getStr == "#alt:localhost"

    let aliases = client_alias.aliasesFromCanonicalContent(content)
    check aliases == @["#main:localhost", "#alt:localhost"]

    let removed = client_alias.aliasContentWithout(content, "#main:localhost")
    check removed["alias"].getStr == "#alt:localhost"
    check not removed.hasKey("alt_aliases")
    check client_alias.aliasWriteResponse().len == 0
    check client_alias.aliasNotFound().errcode == "M_NOT_FOUND"

  test "room aliases helpers enforce access and emit aliases array":
    let payload = client_room_aliases.aliasesPayload(["#a:localhost", "", "#b:localhost"])
    check payload["aliases"].len == 2
    check payload["aliases"][0].getStr == "#a:localhost"
    check client_room_aliases.aliasesAccessPolicy(false).errcode == "M_FORBIDDEN"
    check client_room_aliases.aliasesAccessPolicy(true).ok

  test "directory helpers parse public rooms requests and visibility payloads":
    let request = client_directory.parsePublicRoomsRequest(%*{
      "filter": {"generic_search_term": "Lobby"},
      "limit": 25,
      "since": "n50"
    })
    check request.searchTerm == "lobby"
    check request.limit == 25
    check request.startIndex == 50

    let previous = client_directory.parsePublicRoomsRequest(%*{"limit": 25, "since": "p50"})
    check previous.startIndex == 25

    let chunk = client_directory.publicRoomChunk(
      "!room:localhost",
      "Lobby",
      3,
      canonicalAlias = "#lobby:localhost",
      worldReadable = true,
      guestCanJoin = true,
    )
    check chunk["room_id"].getStr == "!room:localhost"
    check chunk["canonical_alias"].getStr == "#lobby:localhost"
    check chunk["world_readable"].getBool

    let response = client_directory.publicRoomsResponse(%*[chunk], 1, nextBatch = "n1")
    check response["chunk"][0]["name"].getStr == "Lobby"
    check response["total_room_count_estimate"].getInt == 1
    check response["next_batch"].getStr == "n1"

    check client_directory.visibilityPayload("public")["visibility"].getStr == "public"
    check client_directory.visibilityToJoinRule("public").joinRule == "public"
    check client_directory.visibilityToJoinRule("private").joinRule == "invite"
    check client_directory.visibilityToJoinRule("secret").errcode == "M_INVALID_PARAM"
    check client_directory.visibilityWriteResponse().len == 0

  test "user directory helpers cap limits, match search and build response shape":
    check client_user_directory.userDirectoryLimit(%*{"limit": 1000}) == client_user_directory.LimitMax
    check client_user_directory.userDirectoryLimit(%*{"limit": 0}) == 1
    check client_user_directory.userMatchesSearch("@alice:localhost", "alice", "Alice A.", "ali")
    check client_user_directory.userMatchesSearch("@alice:localhost", "alice", "Alice A.", "")
    check not client_user_directory.userMatchesSearch("@bob:localhost", "bob", "Bob", "ali")

    let item = client_user_directory.userDirectoryItem("@alice:localhost", "Alice", "mxc://localhost/avatar")
    check item["display_name"].getStr == "Alice"
    check item["avatar_url"].getStr == "mxc://localhost/avatar"

    let response = client_user_directory.userDirectoryResponse([item], limited = true)
    check response["limited"].getBool
    check response["results"][0]["user_id"].getStr == "@alice:localhost"

  test "space helpers cap hierarchy inputs and preserve client response shape":
    check client_space.hierarchyLimit(0) == client_space.HierarchyLimitDefault
    check client_space.hierarchyLimit(1000) == client_space.HierarchyLimitMax
    check client_space.hierarchyDepth(0) == client_space.HierarchyDepthDefault
    check client_space.hierarchyDepth(1000) == client_space.HierarchyDepthMax

    let rooms = %*[
      {"room_id": "!space:localhost"},
      {"room_id": "!child:localhost"}
    ]
    let response = client_space.hierarchyResponse(rooms, nextBatch = "token")
    check response["rooms"].len == 2
    check response["next_batch"].getStr == "token"
    check client_space.hierarchyAccessPolicy(roomExists = false, canView = true).errcode == "M_NOT_FOUND"
    check client_space.hierarchyAccessPolicy(roomExists = true, canView = false).errcode == "M_FORBIDDEN"
    check client_space.hierarchyAccessPolicy(roomExists = true, canView = true).ok
