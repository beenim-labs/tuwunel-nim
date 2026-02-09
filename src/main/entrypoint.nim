import std/[asynchttpserver, asyncdispatch, json, os, strformat, strutils]
import main/args
import core/logging
import core/config_loader
import core/config_values

proc boolEnv(name: string; defaultValue = false): bool =
  let raw = getEnv(name)
  if raw.len == 0:
    return defaultValue
  case raw.toLowerAscii()
  of "1", "true", "yes", "on":
    true
  of "0", "false", "no", "off":
    false
  else:
    defaultValue

proc getConfigValue(cfg: FlatConfig; keys: openArray[string]): ConfigValue =
  for key in keys:
    if key in cfg:
      return cfg[key]
  newNullValue()

proc getConfigString(cfg: FlatConfig; keys: openArray[string]; fallback: string): string =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvString:
    value.s
  of cvInt:
    $value.i
  of cvFloat:
    $value.f
  of cvBool:
    if value.b: "true" else: "false"
  else:
    fallback

proc getConfigInt(cfg: FlatConfig; keys: openArray[string]; fallback: int): int =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvInt:
    int(value.i)
  of cvFloat:
    int(value.f)
  of cvString:
    try:
      parseInt(value.s)
    except ValueError:
      fallback
  else:
    fallback

proc getConfigBool(cfg: FlatConfig; keys: openArray[string]; fallback: bool): bool =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvBool:
    value.b
  of cvString:
    case value.s.toLowerAscii()
    of "1", "true", "yes", "on":
      true
    of "0", "false", "no", "off":
      false
    else:
      fallback
  else:
    fallback

const
  RustBaselineVersion = "1.4.9"

proc versionsResponse(): JsonNode =
  %*{
    "versions": [
      "r0.0.1",
      "r0.1.0",
      "r0.2.0",
      "r0.3.0",
      "r0.4.0",
      "r0.5.0",
      "r0.6.0",
      "r0.6.1",
      "v1.1",
      "v1.2",
      "v1.3",
      "v1.4",
      "v1.5",
      "v1.10",
      "v1.11"
    ],
    "unstable_features": {
      "fi.mau.msc2659.stable": true,
      "fi.mau.msc2815": true,
      "org.matrix.e2e_cross_signing": true,
      "org.matrix.msc2285.stable": true,
      "org.matrix.msc2836": true,
      "org.matrix.msc2946": true
    }
  }

proc loginTypesResponse(): JsonNode =
  %*{
    "flows": [
      {"type": "m.login.application_service"},
      {"type": "org.matrix.login.jwt"},
      {"type": "m.login.password"},
      {"type": "m.login.token", "get_login_token": true}
    ]
  }

proc matrixError(errcode, message: string): JsonNode =
  %*{
    "errcode": errcode,
    "error": errcode & ": " & message
  }

proc respondJson(req: Request; code: HttpCode; payload: JsonNode) {.async.} =
  let headers = newHttpHeaders({
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
  })
  await req.respond(code, $payload, headers)

proc hasAccessToken(req: Request): bool =
  if req.headers.hasKey("Authorization"):
    let auth = req.headers["Authorization"].strip()
    if auth.len > "Bearer ".len and auth.toLowerAscii().startsWith("bearer "):
      return true
  if req.url.query.len > 0 and req.url.query.contains("access_token="):
    return true
  false

proc hasFederationAuth(req: Request): bool =
  if not req.headers.hasKey("Authorization"):
    return false
  req.headers["Authorization"].strip().toLowerAscii().startsWith("x-matrix")

proc resolveRouteName(path: string): string =
  case path
  of "/_matrix/client/v3/account/whoami", "/_matrix/client/r0/account/whoami":
    return "whoami_route"
  of "/_matrix/client/v3/login", "/_matrix/client/r0/login":
    return "login_route"
  of "/_matrix/client/v3/register", "/_matrix/client/r0/register":
    return "register_route"
  of "/_matrix/client/v3/logout", "/_matrix/client/r0/logout":
    return "logout_route"
  of "/_matrix/client/v3/logout/all", "/_matrix/client/r0/logout/all":
    return "logout_all_route"
  of "/_matrix/client/v3/capabilities", "/_matrix/client/r0/capabilities":
    return "get_capabilities_route"
  of "/_matrix/key/v2/server":
    return "/_matrix/key/v2/server"
  of "/client/server.json":
    return "/client/server.json"
  of "/_tuwunel/server_version":
    return "/_tuwunel/server_version"
  of "/.well-known/matrix/server":
    return "/.well-known/matrix/server"
  else:
    discard

  if path.startsWith("/_matrix/key/v2/server/"):
    return "/_matrix/key/v2/server/{key_id}"
  if path.startsWith("/_matrix/federation/"):
    return "/_matrix/federation/{*path}"
  if path.startsWith("/_matrix/key/"):
    return "/_matrix/key/{*path}"
  if path.startsWith("/_matrix/media/v1/"):
    return "/_matrix/media/v1/{*path}"
  if path.startsWith("/_matrix/media/v3/download/"):
    return "/_matrix/media/v3/download/{*path}"
  if path.startsWith("/_matrix/media/v3/thumbnail/"):
    return "/_matrix/media/v3/thumbnail/{*path}"
  if path.startsWith("/_matrix/media/r0/download/"):
    return "/_matrix/media/r0/download/{*path}"
  if path.startsWith("/_matrix/media/r0/thumbnail/"):
    return "/_matrix/media/r0/thumbnail/{*path}"
  ""

proc routeNeedsAccessToken(routeName: string): bool =
  case routeName
  of "whoami_route", "logout_route", "logout_all_route", "get_capabilities_route",
      "/_matrix/media/v1/{*path}":
    true
  else:
    false

proc routeNeedsFederationAuth(routeName: string): bool =
  case routeName
  of "/_matrix/federation/{*path}", "/_matrix/key/v2/server", "/_matrix/key/v2/server/{key_id}",
      "/_matrix/key/{*path}":
    true
  else:
    false

proc routeBlockedWhenFederationDisabled(routeName: string): bool =
  case routeName
  of "/_matrix/federation/{*path}", "/_matrix/key/v2/server", "/_matrix/key/v2/server/{key_id}",
      "/_matrix/key/{*path}":
    true
  else:
    false

proc isRegisterAvailablePath(path: string): bool =
  path.startsWith("/_matrix/client/v3/register/available") or
    path.startsWith("/_matrix/client/r0/register/available")

proc isPublicRoomsPath(path: string): bool =
  path == "/_matrix/client/v3/publicRooms" or
    path == "/_matrix/client/r0/publicRooms"

proc isAuthGetPath(path: string): bool =
  case path
  of "/_matrix/client/v3/thirdparty/protocols",
      "/_matrix/client/r0/thirdparty/protocols",
      "/_matrix/client/v3/voip/turnServer",
      "/_matrix/client/r0/voip/turnServer",
      "/_matrix/client/v3/sync",
      "/_matrix/client/r0/sync",
      "/_matrix/client/v3/devices",
      "/_matrix/client/r0/devices",
      "/_matrix/client/v3/account/3pid",
      "/_matrix/client/r0/account/3pid",
      "/_matrix/client/v3/notifications",
      "/_matrix/client/r0/notifications",
      "/_matrix/client/v3/pushers",
      "/_matrix/client/r0/pushers",
      "/_matrix/client/v3/joined_rooms",
      "/_matrix/client/r0/joined_rooms":
    return true
  else:
    discard

  if path.startsWith("/_matrix/client/v3/keys/changes") or path.startsWith("/_matrix/client/r0/keys/changes"):
    return true
  if path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/"):
    if path.endsWith("/members") or path.contains("/event/") or path.contains("/context/") or
        path.endsWith("/messages") or path.endsWith("/aliases"):
      return true
  false

proc isPostAuthPath(path: string): bool =
  case path
  of "/_matrix/client/v3/keys/query",
      "/_matrix/client/r0/keys/query",
      "/_matrix/client/v3/search",
      "/_matrix/client/r0/search",
      "/_matrix/client/v3/user_directory/search",
      "/_matrix/client/r0/user_directory/search":
    true
  else:
    false

proc isMediaConfigOrDownloadPath(path: string): bool =
  path == "/_matrix/media/v3/config" or
    path.startsWith("/_matrix/media/v3/download/") or
    path.startsWith("/_matrix/media/v3/thumbnail/") or
    path == "/_matrix/media/r0/config" or
    path.startsWith("/_matrix/media/r0/download/") or
    path.startsWith("/_matrix/media/r0/thumbnail/") or
    path.startsWith("/_matrix/media/v1/")

proc isMediaPreviewPath(path: string): bool =
  path.startsWith("/_matrix/media/v3/preview_url") or
    path.startsWith("/_matrix/media/r0/preview_url")

proc isProfilePath(path: string): bool =
  path.startsWith("/_matrix/client/v3/profile/") or
    path.startsWith("/_matrix/client/r0/profile/")

proc isDirectoryRoomPath(path: string): bool =
  path.startsWith("/_matrix/client/v3/directory/room/") or
    path.startsWith("/_matrix/client/r0/directory/room/")

proc isDeviceCollectionPath(path: string): bool =
  path == "/_matrix/client/v3/devices" or path == "/_matrix/client/r0/devices"

proc isDeviceDetailPath(path: string): bool =
  path.startsWith("/_matrix/client/v3/devices/") or
    path.startsWith("/_matrix/client/r0/devices/")

proc isDeleteDevicesPath(path: string): bool =
  path == "/_matrix/client/v3/delete_devices" or path == "/_matrix/client/r0/delete_devices"

proc isPushersSetPath(path: string): bool =
  path == "/_matrix/client/v3/pushers/set" or path == "/_matrix/client/r0/pushers/set"

proc isRoomStatePath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/state/")

proc isCreateRoomPath(path: string): bool =
  path == "/_matrix/client/v3/createRoom" or path == "/_matrix/client/r0/createRoom"

proc isEventsPath(path: string): bool =
  path == "/_matrix/client/v3/events" or path == "/_matrix/client/r0/events"

proc isKeysUploadOrClaimPath(path: string): bool =
  case path
  of "/_matrix/client/v3/keys/upload",
      "/_matrix/client/r0/keys/upload",
      "/_matrix/client/v3/keys/claim",
      "/_matrix/client/r0/keys/claim":
    true
  else:
    false

proc isUserFilterPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/user/") or path.startsWith("/_matrix/client/r0/user/")) and
    path.contains("/filter")

proc isUserAccountDataPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/user/") or path.startsWith("/_matrix/client/r0/user/")) and
    path.contains("/account_data/")

proc isRoomAccountDataPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/account_data/")

proc isRoomReadMarkersPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.endsWith("/read_markers")

proc isRoomTypingPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/typing/")

proc isRoomReceiptPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.contains("/receipt/")

proc isRoomInitialSyncPath(path: string): bool =
  (path.startsWith("/_matrix/client/v3/rooms/") or path.startsWith("/_matrix/client/r0/rooms/")) and
    path.endsWith("/initialSync")

proc isUnstableSummaryPath(path: string): bool =
  path.startsWith("/_matrix/client/unstable/im.nheko.summary/rooms/") and
    path.endsWith("/summary")

proc methodNotAllowed(req: Request) {.async.} =
  await respondJson(req, Http405, matrixError("M_UNRECOGNIZED", "Method Not Allowed"))

proc notFound(req: Request) {.async.} =
  await respondJson(req, Http404, matrixError("M_UNRECOGNIZED", "Not Found"))

proc notFoundWithCode(req: Request; errcode: string) {.async.} =
  await respondJson(req, Http404, matrixError(errcode, "Not Found"))

proc runNativeServer(cfg: LoadedConfig): int =
  let bindAddress = getConfigString(cfg.values, ["global.address", "address"], "127.0.0.1")
  let bindPort = getConfigInt(cfg.values, ["global.port", "port"], 8008)
  let serverName = getConfigString(cfg.values, ["global.server_name", "server_name"], "localhost")
  let listening = getConfigBool(cfg.values, ["global.listening", "listening"], true)
  let allowFederation = getConfigBool(
    cfg.values,
    ["global.allow_federation", "allow_federation"],
    true,
  )

  if not listening:
    info("Config sets listening=false; native runtime started without binding sockets")
    return 0

  var server = newAsyncHttpServer()

  proc cb(req: Request) {.async, gcsafe.} =
    let path = req.url.path
    let tokenPresent = hasAccessToken(req)
    let fedAuth = hasFederationAuth(req)

    if path == "/_matrix/client/versions":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await respondJson(req, Http200, versionsResponse())
      return

    if path == "/_matrix/client/v3/login" or path == "/_matrix/client/r0/login":
      if req.reqMethod == HttpGet:
        await respondJson(req, Http200, loginTypesResponse())
        return

    if isRegisterAvailablePath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if tokenPresent:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      else:
        await respondJson(req, Http200, %*{"available": true})
      return

    if isPublicRoomsPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if req.reqMethod == HttpGet:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing or invalid access token."))
      elif not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isProfilePath(path):
      if req.reqMethod == HttpGet:
        if not tokenPresent:
          await notFoundWithCode(req, "M_NOT_FOUND")
        else:
          await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
        return
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDirectoryRoomPath(path):
      if req.reqMethod == HttpGet:
        if not tokenPresent:
          await notFoundWithCode(req, "M_NOT_FOUND")
        else:
          await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
        return
      if req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDeviceCollectionPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDeviceDetailPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut and req.reqMethod != HttpDelete:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isDeleteDevicesPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isPushersSetPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomStatePath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isCreateRoomPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isEventsPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isKeysUploadOrClaimPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isUserFilterPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isUserAccountDataPath(path):
      if req.reqMethod != HttpGet and req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomAccountDataPath(path):
      await notFound(req)
      return

    if isRoomReadMarkersPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomTypingPath(path):
      if req.reqMethod != HttpPut:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomReceiptPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isRoomInitialSyncPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isUnstableSummaryPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Forbidden."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isPostAuthPath(path):
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isAuthGetPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if isMediaConfigOrDownloadPath(path):
      await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Unauthenticated media is disabled."))
      return

    if isMediaPreviewPath(path):
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not tokenPresent:
        await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      else:
        await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    if path == "/_matrix/client/v3/register" or path == "/_matrix/client/r0/register":
      if req.reqMethod == HttpGet:
        await methodNotAllowed(req)
        return
    if path == "/_matrix/client/v3/logout" or path == "/_matrix/client/r0/logout":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
    if path == "/_matrix/client/v3/logout/all" or path == "/_matrix/client/r0/logout/all":
      if req.reqMethod != HttpPost:
        await methodNotAllowed(req)
        return
    if path == "/_matrix/client/v3/capabilities" or path == "/_matrix/client/r0/capabilities":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return

    if path == "/_tuwunel/server_version":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await respondJson(req, Http200, %*{
        "name": "Tuwunel",
        "version": RustBaselineVersion,
      })
      return

    if path == "/_tuwunel/local_user_count":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Forbidden."))
      return

    if path == "/client/server.json":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      await notFoundWithCode(req, "M_NOT_FOUND")
      return

    if path == "/.well-known/matrix/server":
      if req.reqMethod != HttpGet:
        await methodNotAllowed(req)
        return
      if not allowFederation:
        await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
      else:
        await respondJson(req, Http200, %*{"m.server": serverName})
      return

    let routeName = resolveRouteName(path)
    if routeName.len == 0:
      await notFound(req)
      return

    if routeBlockedWhenFederationDisabled(routeName) and not allowFederation:
      await respondJson(req, Http403, matrixError("M_FORBIDDEN", "Federation is disabled."))
      return

    if routeNeedsFederationAuth(routeName) and not fedAuth:
      await respondJson(req, Http401, matrixError("M_UNAUTHORIZED", "Missing federation authentication."))
      return

    if routeNeedsAccessToken(routeName) and not tokenPresent:
      await respondJson(req, Http401, matrixError("M_MISSING_TOKEN", "Missing access token."))
      return

    if routeNeedsAccessToken(routeName) and tokenPresent:
      await respondJson(req, Http401, matrixError("M_UNKNOWN_TOKEN", "Unknown access token."))
      return

    await respondJson(
      req,
      Http501,
      matrixError("M_NOT_YET_IMPLEMENTED", "Route registered but not yet behaviorally ported: " & routeName),
    )

  info(fmt"Starting native Nim runtime on {bindAddress}:{bindPort}")
  info("Rust delegation is disabled in runtime startup path")
  waitFor server.serve(Port(bindPort), cb, address = bindAddress)
  0

proc main*(): int =
  info("Starting native Nim runtime")

  let a = parseArgs()

  if a.showVersion:
    echo "tuwunel-nim " & Version
    return 0

  if a.showHelp:
    echo usage()
    return 0

  if a.unknown.len > 0:
    return die("Unknown flags: " & $a.unknown)

  let cfgRes = loadConfigCompatibility(a)
  if not cfgRes.ok:
    return die(cfgRes.err)

  for p in cfgRes.cfg.configPaths:
    if not fileExists(p):
      warn(fmt"Config path does not exist yet: {p}")

  info("Bootstrapped compatibility config loader for tuwunel-nim")
  info(
    fmt"config_paths={cfgRes.cfg.configPaths.len} loaded_files={cfgRes.cfg.stats.loadedFiles.len} " &
    fmt"env_overrides={cfgRes.cfg.stats.envOverrides.len} option_overrides={cfgRes.cfg.stats.optionOverrides.len}"
  )
  debug("effective_config:\n" & renderFlatConfig(cfgRes.cfg.values))

  if boolEnv("TUWUNEL_NIM_BOOTSTRAP_ONLY", false):
    info("Bootstrap-only mode enabled; skipping runtime server loop")
    return 0

  runNativeServer(cfgRes.cfg)
