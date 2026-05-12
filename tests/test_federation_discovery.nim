import std/[json, unittest]

import api/server/openid as server_openid_api
import api/server/query as server_query_api
import api/server/version as server_version_api
import api/server/well_known as server_well_known_api

suite "Federation discovery and query API helpers":
  test "version payload preserves Tuwunel server metadata":
    let payload = server_version_api.federationVersionPayload("1.4.9")
    check payload["server"]["name"].getStr("") == "Tuwunel"
    check payload["server"]["version"].getStr("") == "1.4.9"
    check payload["server"]["compiler"].getStr("") == "nim"

  test "well-known server payload rejects missing config":
    check not server_well_known_api.wellKnownServerPayload("").ok
    let payload = server_well_known_api.wellKnownServerPayload(" matrix.example:443 ")
    check payload.ok
    check payload.payload["m.server"].getStr("") == "matrix.example:443"

  test "OpenID userinfo returns Matrix subject only for known users":
    check not server_openid_api.openIdUserInfoPayload("").ok
    let payload = server_openid_api.openIdUserInfoPayload("@alice:localhost")
    check payload.ok
    check payload.payload["sub"].getStr("") == "@alice:localhost"

  test "directory and profile query payloads preserve Rust response shape":
    let directory = server_query_api.directoryPayload("!room:localhost", @["localhost"])
    check directory.ok
    check directory.payload["room_id"].getStr("") == "!room:localhost"
    check directory.payload["servers"][0].getStr("") == "localhost"
    check not server_query_api.directoryPayload("", @["localhost"]).ok

    let profile = %*{
      "displayname": "Alice",
      "avatar_url": "mxc://localhost/alice",
      "m.tz": "Europe/Stockholm"
    }
    let full = server_query_api.profilePayload(profile)
    check full.ok
    check full.payload["displayname"].getStr("") == "Alice"
    let field = server_query_api.profilePayload(profile, "avatar_url")
    check field.ok
    check field.payload.len == 1
    check field.payload["avatar_url"].getStr("") == "mxc://localhost/alice"
    check not server_query_api.profilePayload(profile, "missing").ok
