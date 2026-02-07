import std/[json, options, strutils, tables]
import api/generated_route_runtime
import api/router/args
import api/router/auth
import api/router/request
import api/router/response
import api/router/state

const
  RustPath* = "api/router/handler.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"
  CompatServerName = "tuwunel-nim"
  CompatServerVersion = "0.1.0"

type
  ApiRouteHandler* = proc(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse {.closure.}

  ApiHandlerRegistry* = Table[string, ApiRouteHandler]

proc routeKindLabel(kind: RouteKind): string =
  case kind
  of rkClient:
    "client"
  of rkServer:
    "server"
  of rkManual:
    "manual"
  of rkUnknown:
    "unknown"

proc parseBodyJson(req: ApiRequest): Option[JsonNode] =
  if req.body.strip().len == 0:
    return none(JsonNode)
  try:
    some(parseJson(req.body))
  except CatchableError:
    none(JsonNode)

proc bodyString(node: JsonNode; key: string): string =
  if node.kind != JObject or key notin node:
    return ""
  let value = node[key]
  if value.kind == JString:
    return value.getStr()
  if value.kind in {JInt, JFloat, JBool}:
    return $value
  ""

proc bodyBool(node: JsonNode; key: string; fallback: bool): bool =
  if node.kind != JObject or key notin node:
    return fallback
  let value = node[key]
  case value.kind
  of JBool:
    value.getBool()
  of JString:
    let raw = value.getStr().toLowerAscii()
    raw in ["true", "1", "yes", "on"]
  else:
    fallback

proc bodyStringArray(node: JsonNode; key: string): seq[string] =
  result = @[]
  if node.kind != JObject or key notin node:
    return
  let value = node[key]
  if value.kind != JArray:
    return
  for item in value:
    case item.kind
    of JString:
      result.add(item.getStr())
    of JInt, JFloat, JBool:
      result.add($item)
    else:
      discard

proc extractLoginUser(node: JsonNode): string =
  let direct = bodyString(node, "user")
  if direct.len > 0:
    return direct
  if node.kind == JObject and "identifier" in node:
    let identifier = node["identifier"]
    let nested = bodyString(identifier, "user")
    if nested.len > 0:
      return nested
  ""

proc tokenFromRequest(req: ApiRequest): Option[string] =
  if req.accessToken.isSome and req.accessToken.get().len > 0:
    return req.accessToken

  let authHeader = req.getHeader("authorization")
  if authHeader.isSome:
    let value = authHeader.get()
    if value.toLowerAscii().startsWith("bearer "):
      return some(value[7 .. ^1].strip())

  let queryToken = req.getQueryParam("access_token")
  if queryToken.isSome and queryToken.get().len > 0:
    return queryToken

  none(string)

proc unknownTokenResponse(spec: RouteSpec): ApiResponse =
  matrixErrorResponse(401, "M_UNKNOWN_TOKEN", "Unknown access token", spec.name, spec.kind)

proc resolveSessionFromRequest(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec): tuple[ok: bool, session: SessionRecord] =
  let token = tokenFromRequest(req)
  if token.isNone:
    return (false, SessionRecord())
  state.resolveSession(token.get())

proc userPayload(user: UserRecord): JsonNode =
  result = newJObject()
  result["user_id"] = %user.userId
  result["displayname"] = %user.displayName
  result["avatar_url"] = %user.avatarUrl
  result["presence"] = %user.presence
  result["deactivated"] = %user.deactivated

proc asJsonRouteSummary(
    state: ApiRouterState; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): JsonNode =
  result = newJObject()
  result["route"] = %spec.name
  result["kind"] = %routeKindLabel(spec.kind)
  result["requires_auth"] = %spec.requiresAuth
  result["federation_only"] = %spec.federationOnly
  result["path_segments"] = %routeArgs.pathSegments.len
  result["query_params"] = %routeArgs.queryParams.len
  result["access_token"] = %ctx.accessTokenPresent
  result["federation"] = %ctx.federationAuthenticated
  result["local_users"] = %state.localUserCount()

proc requestedDeviceId(routeArgs: RouteArgs; body: Option[JsonNode]; fallback: string): string =
  let fromQuery = routeArgs.queryParamOr("device_id", "").strip()
  if fromQuery.len > 0:
    return fromQuery
  if body.isSome:
    let fromBody = bodyString(body.get(), "device_id").strip()
    if fromBody.len > 0:
      return fromBody
  fallback

proc decodePathSegment(input: string): string =
  result = newStringOfCap(input.len)
  var i = 0
  while i < input.len:
    if input[i] == '%' and i + 2 < input.len:
      let hex = input[i + 1 .. i + 2]
      try:
        result.add(char(parseHexInt(hex)))
        i += 3
        continue
      except ValueError:
        discard
    if input[i] == '+':
      result.add(' ')
    else:
      result.add(input[i])
    inc i

proc pathSegmentAfter(routeArgs: RouteArgs; marker: string): string =
  for idx in 0 ..< routeArgs.pathSegments.len:
    if routeArgs.pathSegments[idx] != marker:
      continue
    if idx + 1 < routeArgs.pathSegments.len:
      return decodePathSegment(routeArgs.pathSegments[idx + 1])
  ""

proc pathSegmentAfterN(routeArgs: RouteArgs; marker: string; step: int): string =
  for idx in 0 ..< routeArgs.pathSegments.len:
    if routeArgs.pathSegments[idx] != marker:
      continue
    let target = idx + step
    if target >= 0 and target < routeArgs.pathSegments.len:
      return decodePathSegment(routeArgs.pathSegments[target])
  ""

proc pathLast(routeArgs: RouteArgs): string =
  if routeArgs.pathSegments.len == 0:
    return ""
  decodePathSegment(routeArgs.pathSegments[^1])

proc targetRoomIdOrAlias(routeArgs: RouteArgs): string =
  let fromQuery = routeArgs.queryParamOr("room_id", "").strip()
  if fromQuery.len > 0:
    return decodePathSegment(fromQuery)

  let fromRooms = pathSegmentAfter(routeArgs, "rooms")
  if fromRooms.len > 0:
    return fromRooms

  let fromJoin = pathSegmentAfter(routeArgs, "join")
  if fromJoin.len > 0:
    return fromJoin

  let fromSummary = pathSegmentAfter(routeArgs, "summary")
  if fromSummary.len > 0:
    return fromSummary
  ""

proc targetAlias(routeArgs: RouteArgs): string =
  let fromQuery = routeArgs.queryParamOr("room_alias", "").strip()
  if fromQuery.len > 0:
    return decodePathSegment(fromQuery)
  let fromBodyStyle = pathSegmentAfter(routeArgs, "room")
  if fromBodyStyle.len > 0:
    return fromBodyStyle
  if routeArgs.pathSegments.len > 0 and routeArgs.pathSegments[^2] == "room":
    return pathLast(routeArgs)
  ""

proc eventTypeFromPath(routeArgs: RouteArgs): string =
  let fromSend = pathSegmentAfterN(routeArgs, "send", 1)
  if fromSend.len > 0:
    return fromSend
  let fromState = pathSegmentAfterN(routeArgs, "state", 1)
  if fromState.len > 0:
    return fromState
  routeArgs.pathParamOr("event_type", "")

proc stateKeyFromPath(routeArgs: RouteArgs): string =
  let fromState = pathSegmentAfterN(routeArgs, "state", 2)
  if fromState.len > 0:
    return fromState
  ""

proc eventIdFromPath(routeArgs: RouteArgs): string =
  let fromEvent = pathSegmentAfter(routeArgs, "event")
  if fromEvent.len > 0:
    return fromEvent
  routeArgs.pathParamOr("event_id", "")

proc sessionUserOrUnknown(state: ApiRouterState; req: ApiRequest; spec: RouteSpec): tuple[ok: bool, userId: string, session: SessionRecord] =
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return (false, "", SessionRecord())
  (true, resolved.session.userId, resolved.session)

proc eventPayload(event: RoomEventRecord): JsonNode =
  result = newJObject()
  result["event_id"] = %event.eventId
  result["room_id"] = %event.roomId
  result["sender"] = %event.sender
  result["type"] = %event.eventType
  result["origin_server_ts"] = %event.originServerTs
  result["content"] = event.content
  if event.stateKey.isSome:
    result["state_key"] = %event.stateKey.get()

proc versionsHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard state
  discard req
  discard routeArgs
  discard ctx
  var payload = newJObject()
  payload["versions"] = %*[
    "r0.0.1",
    "r0.6.1",
    "v1.1",
    "v1.2",
    "v1.3",
    "v1.4",
    "v1.5",
    "v1.6",
    "v1.7",
    "v1.8",
    "v1.9",
    "v1.10",
    "v1.11",
  ]
  payload["unstable_features"] = newJObject()
  successResponse(spec.name, spec.kind, payload)

proc loginTypesHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard state
  discard req
  discard routeArgs
  discard ctx
  var passwordFlow = newJObject()
  passwordFlow["type"] = %"m.login.password"
  var tokenFlow = newJObject()
  tokenFlow["type"] = %"m.login.token"
  var payload = newJObject()
  payload["flows"] = %*[passwordFlow, tokenFlow]
  successResponse(spec.name, spec.kind, payload)

proc registerAvailableHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let username = routeArgs.queryParamOr("username", "").strip()
  if username.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing username", spec.name, spec.kind)

  let userId = normalizeUserId(username)
  if state.userExists(userId):
    return matrixErrorResponse(400, "M_USER_IN_USE", "User already exists", spec.name, spec.kind)

  var payload = newJObject()
  payload["available"] = %true
  successResponse(spec.name, spec.kind, payload)

proc registerHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let bodyOpt = parseBodyJson(req)
  var username = ""
  var password = ""
  var displayName = ""
  var deviceId = ""
  if bodyOpt.isSome:
    let body = bodyOpt.get()
    username = bodyString(body, "username").strip()
    password = bodyString(body, "password")
    displayName = bodyString(body, "initial_device_display_name")
    deviceId = bodyString(body, "device_id").strip()

  let userId =
    if username.len > 0: normalizeUserId(username)
    else: state.nextUserId()

  if password.len == 0:
    password = "nim-password"
  if displayName.len == 0:
    displayName = userId

  if not state.createUser(userId, password, displayName):
    return matrixErrorResponse(400, "M_USER_IN_USE", "User already exists", spec.name, spec.kind)

  let session = state.issueSession(userId, deviceId = deviceId, deviceDisplayName = displayName)
  var payload = newJObject()
  payload["user_id"] = %session.userId
  payload["access_token"] = %session.token
  payload["device_id"] = %session.deviceId
  payload["home_server"] = %CompatServerName
  successResponse(spec.name, spec.kind, payload)

proc loginHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)

  let body = bodyOpt.get()
  let user = extractLoginUser(body).strip()
  let password = bodyString(body, "password")
  let deviceId = bodyString(body, "device_id").strip()
  let deviceName = bodyString(body, "initial_device_display_name")
  if user.len == 0 or password.len == 0:
    return matrixErrorResponse(400, "M_BAD_JSON", "Missing login user or password", spec.name, spec.kind)

  if not state.verifyPassword(user, password):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Invalid username or password", spec.name, spec.kind)

  let session = state.issueSession(user, deviceId = deviceId, deviceDisplayName = deviceName)
  var payload = newJObject()
  payload["user_id"] = %session.userId
  payload["access_token"] = %session.token
  payload["device_id"] = %session.deviceId
  payload["home_server"] = %CompatServerName
  successResponse(spec.name, spec.kind, payload)

proc whoamiHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)

  var payload = newJObject()
  payload["user_id"] = %resolved.session.userId
  payload["device_id"] = %resolved.session.deviceId
  payload["is_guest"] = %false
  successResponse(spec.name, spec.kind, payload)

proc logoutHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let token = tokenFromRequest(req)
  if token.isNone:
    return unknownTokenResponse(spec)
  if not state.revokeSession(token.get()):
    return unknownTokenResponse(spec)
  successResponse(spec.name, spec.kind, newJObject())

proc logoutAllHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)

  let revoked = state.revokeAllSessions(resolved.session.userId)
  var payload = newJObject()
  payload["revoked"] = %revoked
  successResponse(spec.name, spec.kind, payload)

proc getProfileHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let user = state.getUser(resolved.session.userId)
  if not user.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, userPayload(user.user))

proc getDisplayNameHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let user = state.getUser(resolved.session.userId)
  if not user.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  var payload = newJObject()
  payload["displayname"] = %user.user.displayName
  successResponse(spec.name, spec.kind, payload)

proc setDisplayNameHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let displayName = bodyString(bodyOpt.get(), "displayname")
  if not state.setDisplayName(resolved.session.userId, displayName):
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc getAvatarUrlHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let user = state.getUser(resolved.session.userId)
  if not user.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  var payload = newJObject()
  payload["avatar_url"] = %user.user.avatarUrl
  successResponse(spec.name, spec.kind, payload)

proc setAvatarUrlHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let avatarUrl = bodyString(bodyOpt.get(), "avatar_url")
  if not state.setAvatarUrl(resolved.session.userId, avatarUrl):
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc getPresenceHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let user = state.getUser(resolved.session.userId)
  if not user.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  var payload = newJObject()
  payload["presence"] = %user.user.presence
  successResponse(spec.name, spec.kind, payload)

proc setPresenceHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let presence = bodyString(bodyOpt.get(), "presence").strip()
  if presence.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing presence", spec.name, spec.kind)
  if not state.setPresence(resolved.session.userId, presence):
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc changePasswordHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let body = bodyOpt.get()
  let newPassword = bodyString(body, "new_password")
  if newPassword.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing new_password", spec.name, spec.kind)
  if not state.setPassword(resolved.session.userId, newPassword):
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  if bodyBool(body, "logout_devices", true):
    discard state.revokeAllSessions(resolved.session.userId)
  successResponse(spec.name, spec.kind, newJObject())

proc deactivateHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  if not state.deactivateUser(resolved.session.userId):
    return matrixErrorResponse(404, "M_NOT_FOUND", "User not found", spec.name, spec.kind)
  var payload = newJObject()
  payload["id_server_unbind_result"] = %"success"
  successResponse(spec.name, spec.kind, payload)

proc getDevicesHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  if spec.kind == rkServer and ctx.federationAuthenticated:
    var payload = newJObject()
    payload["devices"] = %*[]
    return successResponse(spec.name, spec.kind, payload)

  discard routeArgs
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)

  var devices = newJArray()
  for session in state.listSessions(resolved.session.userId):
    var device = newJObject()
    device["device_id"] = %session.deviceId
    device["display_name"] = %session.deviceDisplayName
    device["last_seen_ip"] = %"0.0.0.0"
    device["last_seen_ts"] = %0
    devices.add(device)

  var payload = newJObject()
  payload["devices"] = devices
  successResponse(spec.name, spec.kind, payload)

proc getDeviceHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)

  let deviceId = requestedDeviceId(routeArgs, none(JsonNode), resolved.session.deviceId)
  let device = state.sessionForDevice(resolved.session.userId, deviceId)
  if not device.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Device not found", spec.name, spec.kind)

  var payload = newJObject()
  payload["device_id"] = %device.session.deviceId
  payload["display_name"] = %device.session.deviceDisplayName
  successResponse(spec.name, spec.kind, payload)

proc updateDeviceHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)

  let body = bodyOpt.get()
  let deviceId = requestedDeviceId(routeArgs, bodyOpt, resolved.session.deviceId)
  let displayName = bodyString(body, "display_name")
  if not state.updateDeviceDisplayName(resolved.session.userId, deviceId, displayName):
    return matrixErrorResponse(404, "M_NOT_FOUND", "Device not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc deleteDeviceHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)

  let deviceId = requestedDeviceId(routeArgs, none(JsonNode), resolved.session.deviceId)
  if not state.revokeDevice(resolved.session.userId, deviceId):
    return matrixErrorResponse(404, "M_NOT_FOUND", "Device not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc deleteDevicesHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let resolved = resolveSessionFromRequest(state, req, spec)
  if not resolved.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let deviceIds = bodyStringArray(bodyOpt.get(), "devices")
  let revoked = state.revokeDevices(resolved.session.userId, deviceIds)
  var payload = newJObject()
  payload["revoked"] = %revoked
  successResponse(spec.name, spec.kind, payload)

proc createRoomHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)

  let bodyOpt = parseBodyJson(req)
  var name = ""
  var topic = ""
  var visibility = "private"
  var roomAlias = ""
  if bodyOpt.isSome:
    let body = bodyOpt.get()
    name = bodyString(body, "name")
    topic = bodyString(body, "topic")
    visibility = bodyString(body, "visibility")
    let aliasName = bodyString(body, "room_alias_name").strip()
    if aliasName.len > 0:
      roomAlias = normalizeRoomAlias(aliasName)

  let created = state.createRoom(
    creator = auth.userId,
    name = name,
    topic = topic,
    visibility = if visibility.len > 0: visibility else: "private",
    roomAlias = roomAlias,
  )
  if not created.ok:
    let code =
      if created.errcode.len > 0: created.errcode
      else: "M_UNKNOWN"
    let msg =
      if code == "M_ROOM_IN_USE": "Room alias already exists"
      elif code == "M_FORBIDDEN": "User is not allowed to create room"
      else: "Failed to create room"
    return matrixErrorResponse(400, code, msg, spec.name, spec.kind)

  var payload = newJObject()
  payload["room_id"] = %created.roomId
  if roomAlias.len > 0:
    payload["room_alias"] = %roomAlias
  successResponse(spec.name, spec.kind, payload)

proc joinRoomHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)

  let bodyOpt = parseBodyJson(req)
  var roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0 and bodyOpt.isSome:
    roomIdOrAlias = bodyString(bodyOpt.get(), "room_id").strip()
    if roomIdOrAlias.len == 0:
      roomIdOrAlias = bodyString(bodyOpt.get(), "room_alias").strip()
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)

  let joined = state.joinRoom(auth.userId, roomIdOrAlias)
  if not joined.ok:
    let code =
      if joined.errcode.len > 0: joined.errcode
      else: "M_NOT_FOUND"
    let msg =
      if code == "M_FORBIDDEN": "Not allowed to join room"
      else: "Room not found"
    return matrixErrorResponse(if code == "M_FORBIDDEN": 403 else: 404, code, msg, spec.name, spec.kind)

  var payload = newJObject()
  payload["room_id"] = %joined.roomId
  successResponse(spec.name, spec.kind, payload)

proc leaveRoomHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)

  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)
  let left = state.leaveRoom(auth.userId, roomIdOrAlias)
  if not left.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc joinedRoomsHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard routeArgs
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  var payload = newJObject()
  payload["joined_rooms"] = %state.joinedRoomsFor(auth.userId)
  successResponse(spec.name, spec.kind, payload)

proc joinedMembersHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)

  var joined = newJObject()
  for memberId in state.joinedMembersFor(resolved.roomId):
    let user = state.getUser(memberId)
    var member = newJObject()
    if user.ok:
      member["display_name"] = %user.user.displayName
      member["avatar_url"] = %user.user.avatarUrl
    else:
      member["display_name"] = %memberId
      member["avatar_url"] = %""
    joined[memberId] = member
  var payload = newJObject()
  payload["joined"] = joined
  successResponse(spec.name, spec.kind, payload)

proc inviteUserHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let body = bodyOpt.get()
  let target = bodyString(body, "user_id").strip()
  if target.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing user_id", spec.name, spec.kind)

  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)

  let invited = state.inviteUser(auth.userId, target, roomIdOrAlias)
  if not invited.ok:
    let code = if invited.errcode.len > 0: invited.errcode else: "M_NOT_FOUND"
    let status = if code == "M_FORBIDDEN": 403 else: 404
    return matrixErrorResponse(status, code, "Unable to invite user", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc createAliasHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let alias = targetAlias(routeArgs)
  if alias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room alias", spec.name, spec.kind)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let roomIdOrAlias = bodyString(bodyOpt.get(), "room_id").strip()
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room_id", spec.name, spec.kind)
  let resolvedRoom = state.resolveRoom(roomIdOrAlias)
  if not resolvedRoom.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolvedRoom.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  let applied = state.setAlias(resolvedRoom.roomId, alias)
  if not applied.ok:
    let status = if applied.errcode == "M_ROOM_IN_USE": 409 else: 404
    return matrixErrorResponse(status, applied.errcode, "Unable to create alias", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc deleteAliasHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let alias = targetAlias(routeArgs)
  if alias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room alias", spec.name, spec.kind)

  let resolved = state.getAlias(alias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Alias not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  if not state.deleteAlias(alias):
    return matrixErrorResponse(404, "M_NOT_FOUND", "Alias not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, newJObject())

proc getAliasHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let alias = targetAlias(routeArgs)
  if alias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room alias", spec.name, spec.kind)
  let resolved = state.getAlias(alias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Alias not found", spec.name, spec.kind)
  var payload = newJObject()
  payload["room_id"] = %resolved.roomId
  payload["servers"] = %*["tuwunel-nim"]
  successResponse(spec.name, spec.kind, payload)

proc getRoomAliasesHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  var payload = newJObject()
  payload["aliases"] = %state.aliasesForRoom(resolved.roomId)
  successResponse(spec.name, spec.kind, payload)

proc setRoomVisibilityHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)

  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let visibility = bodyString(bodyOpt.get(), "visibility").strip().toLowerAscii()
  if visibility notin ["public", "private"]:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Invalid visibility", spec.name, spec.kind)
  discard state.setRoomVisibility(resolved.roomId, visibility)
  successResponse(spec.name, spec.kind, newJObject())

proc getRoomVisibilityHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  if roomIdOrAlias.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing room identifier", spec.name, spec.kind)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  let visibility = state.getRoomVisibility(resolved.roomId)
  if not visibility.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  var payload = newJObject()
  payload["visibility"] = %visibility.visibility
  successResponse(spec.name, spec.kind, payload)

proc sendMessageEventHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  let room = state.resolveRoom(roomIdOrAlias)
  if not room.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)

  let eventType = eventTypeFromPath(routeArgs)
  if eventType.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing event type", spec.name, spec.kind)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let created = state.createEvent(auth.userId, room.roomId, eventType, bodyOpt.get())
  if not created.ok:
    let code = if created.errcode.len > 0: created.errcode else: "M_FORBIDDEN"
    let status = if code == "M_NOT_FOUND": 404 else: 403
    return matrixErrorResponse(status, code, "Unable to send event", spec.name, spec.kind)

  var payload = newJObject()
  payload["event_id"] = %created.event.eventId
  successResponse(spec.name, spec.kind, payload)

proc sendStateEventHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  let room = state.resolveRoom(roomIdOrAlias)
  if not room.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  let eventType = eventTypeFromPath(routeArgs)
  if eventType.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing event type", spec.name, spec.kind)
  let stateKey = stateKeyFromPath(routeArgs)
  let bodyOpt = parseBodyJson(req)
  if bodyOpt.isNone:
    return matrixErrorResponse(400, "M_BAD_JSON", "Expected JSON body", spec.name, spec.kind)
  let created = state.createEvent(auth.userId, room.roomId, eventType, bodyOpt.get(), stateKey = some(stateKey))
  if not created.ok:
    let code = if created.errcode.len > 0: created.errcode else: "M_FORBIDDEN"
    let status = if code == "M_NOT_FOUND": 404 else: 403
    return matrixErrorResponse(status, code, "Unable to send state event", spec.name, spec.kind)
  var payload = newJObject()
  payload["event_id"] = %created.event.eventId
  successResponse(spec.name, spec.kind, payload)

proc getStateEventsHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  var events = newJArray()
  for event in state.roomState(resolved.roomId):
    events.add(eventPayload(event))
  successResponse(spec.name, spec.kind, events)

proc getStateEventForKeyHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  let eventType = eventTypeFromPath(routeArgs)
  let stateKey = stateKeyFromPath(routeArgs)
  let event = state.roomStateEvent(resolved.roomId, eventType, stateKey)
  if not event.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "State event not found", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, event.event.content)

proc getRoomEventHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let eventId = eventIdFromPath(routeArgs)
  if eventId.len == 0:
    return matrixErrorResponse(400, "M_INVALID_PARAM", "Missing event identifier", spec.name, spec.kind)
  let event = state.getEvent(eventId)
  if not event.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Event not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, event.event.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)
  successResponse(spec.name, spec.kind, eventPayload(event.event))

proc eventsHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let since = parseSinceToken(routeArgs.queryParamOr("from", routeArgs.queryParamOr("since", "0")))
  let chunk = state.streamEventsForUser(auth.userId, since)
  var events = newJArray()
  for event in chunk:
    events.add(eventPayload(event))
  var payload = newJObject()
  payload["chunk"] = events
  payload["start"] = %encodeSinceToken(since)
  payload["end"] = %encodeSinceToken(state.currentStreamPosition())
  successResponse(spec.name, spec.kind, payload)

proc syncHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let since = parseSinceToken(routeArgs.queryParamOr("since", "0"))
  let chunk = state.streamEventsForUser(auth.userId, since)

  var joinedRooms = newJObject()
  for roomId in state.joinedRoomsFor(auth.userId):
    var timelineEvents = newJArray()
    for event in chunk:
      if event.roomId == roomId:
        timelineEvents.add(eventPayload(event))
    var timeline = newJObject()
    timeline["events"] = timelineEvents
    timeline["limited"] = %false
    timeline["prev_batch"] = %encodeSinceToken(since)
    var roomSection = newJObject()
    roomSection["timeline"] = timeline
    joinedRooms[roomId] = roomSection

  var rooms = newJObject()
  rooms["join"] = joinedRooms

  var payload = newJObject()
  payload["next_batch"] = %encodeSinceToken(state.currentStreamPosition())
  payload["rooms"] = rooms
  successResponse(spec.name, spec.kind, payload)

proc syncV5Handler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let since = parseSinceToken(routeArgs.queryParamOr("pos", routeArgs.queryParamOr("since", "0")))
  let chunk = state.streamEventsForUser(auth.userId, since)
  var rooms = newJObject()
  for roomId in state.joinedRoomsFor(auth.userId):
    var timeline = newJArray()
    for event in chunk:
      if event.roomId == roomId:
        timeline.add(eventPayload(event))
    var roomPayload = newJObject()
    roomPayload["timeline"] = timeline
    rooms[roomId] = roomPayload

  var payload = newJObject()
  payload["pos"] = %encodeSinceToken(state.currentStreamPosition())
  payload["rooms"] = rooms
  payload["lists"] = newJObject()
  successResponse(spec.name, spec.kind, payload)

proc roomInitialSyncHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  let auth = sessionUserOrUnknown(state, req, spec)
  if not auth.ok:
    return unknownTokenResponse(spec)
  let roomIdOrAlias = targetRoomIdOrAlias(routeArgs)
  let resolved = state.resolveRoom(roomIdOrAlias)
  if not resolved.ok:
    return matrixErrorResponse(404, "M_NOT_FOUND", "Room not found", spec.name, spec.kind)
  if not state.isJoined(auth.userId, resolved.roomId):
    return matrixErrorResponse(403, "M_FORBIDDEN", "Not joined to room", spec.name, spec.kind)

  var stateEvents = newJArray()
  for event in state.roomState(resolved.roomId):
    stateEvents.add(eventPayload(event))
  var messages = newJArray()
  for event in state.roomTimeline(resolved.roomId, limit = 20):
    messages.add(eventPayload(event))

  var payload = newJObject()
  payload["room_id"] = %resolved.roomId
  payload["membership"] = %"join"
  payload["state"] = stateEvents
  payload["messages"] = messages
  successResponse(spec.name, spec.kind, payload)

proc publicRoomsHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard ctx
  var chunk = newJArray()
  for room in state.publicRooms():
    var entry = newJObject()
    entry["room_id"] = %room.roomId
    entry["name"] = %room.name
    entry["topic"] = %room.topic
    entry["canonical_alias"] = %room.canonicalAlias
    entry["num_joined_members"] = %state.joinedMembersFor(room.roomId).len
    entry["world_readable"] = %false
    entry["guest_can_join"] = %false
    chunk.add(entry)
  var payload = newJObject()
  payload["chunk"] = chunk
  payload["total_room_count_estimate"] = %chunk.len
  payload["start"] = %"s0"
  payload["end"] = %encodeSinceToken(state.currentStreamPosition())
  successResponse(spec.name, spec.kind, payload)

proc serverVersionHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard state
  discard req
  discard routeArgs
  discard ctx
  var server = newJObject()
  server["name"] = %CompatServerName
  server["version"] = %CompatServerVersion
  var payload = newJObject()
  payload["server"] = server
  successResponse(spec.name, spec.kind, payload)

proc wellKnownServerHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard state
  discard req
  discard routeArgs
  discard ctx
  var payload = newJObject()
  payload["m.server"] = %"localhost:8448"
  successResponse(spec.name, spec.kind, payload)

proc wellKnownClientHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard state
  discard req
  discard routeArgs
  discard ctx
  var hs = newJObject()
  hs["base_url"] = %"https://localhost:8448"
  var payload = newJObject()
  payload["m.homeserver"] = hs
  successResponse(spec.name, spec.kind, payload)

proc localUserCountHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  discard routeArgs
  discard ctx
  var payload = newJObject()
  payload["count"] = %state.localUserCount()
  successResponse(spec.name, spec.kind, payload)

proc genericImplementedHandler(
    state: ApiRouterState; req: ApiRequest; spec: RouteSpec; routeArgs: RouteArgs; ctx: ApiAuthContext): ApiResponse =
  discard req
  successResponse(spec.name, spec.kind, asJsonRouteSummary(state, spec, routeArgs, ctx))

proc defaultHandlerRegistry*(): ApiHandlerRegistry =
  result = initTable[string, ApiRouteHandler]()
  result["get_supported_versions_route"] = versionsHandler
  result["get_login_types_route"] = loginTypesHandler
  result["get_register_available_route"] = registerAvailableHandler
  result["register_route"] = registerHandler
  result["login_route"] = loginHandler
  result["whoami_route"] = whoamiHandler
  result["logout_route"] = logoutHandler
  result["logout_all_route"] = logoutAllHandler
  result["get_profile_route"] = getProfileHandler
  result["set_displayname_route"] = setDisplayNameHandler
  result["get_displayname_route"] = getDisplayNameHandler
  result["set_avatar_url_route"] = setAvatarUrlHandler
  result["get_avatar_url_route"] = getAvatarUrlHandler
  result["set_presence_route"] = setPresenceHandler
  result["get_presence_route"] = getPresenceHandler
  result["change_password_route"] = changePasswordHandler
  result["deactivate_route"] = deactivateHandler
  result["get_devices_route"] = getDevicesHandler
  result["get_device_route"] = getDeviceHandler
  result["update_device_route"] = updateDeviceHandler
  result["delete_device_route"] = deleteDeviceHandler
  result["delete_devices_route"] = deleteDevicesHandler
  result["get_server_version_route"] = serverVersionHandler
  result["/_tuwunel/server_version"] = serverVersionHandler
  result["/.well-known/matrix/server"] = wellKnownServerHandler
  result["/client/server.json"] = wellKnownClientHandler
  result["/_tuwunel/local_user_count"] = localUserCountHandler

proc routeErrorToResponse(routeName: string; routeKind: RouteKind; err: RouteError): ApiResponse =
  matrixErrorResponse(err.status, err.errcode, err.error, routeName, routeKind)

proc dispatchApiRequest*(
    state: ApiRouterState; req: ApiRequest; handlers = defaultHandlerRegistry()): ApiResponse =
  if state.isNil:
    return matrixErrorResponse(500, "M_UNKNOWN", "Router state unavailable", req.effectiveRouteName(), rkUnknown)

  let routeName = req.effectiveRouteName()
  let matches = lookupRoutes(routeName)
  if matches.len == 0:
    return matrixErrorResponse(404, "M_UNRECOGNIZED", "Unrecognized route: " & routeName, routeName, rkUnknown)

  let ctx = buildAuthContext(req)
  let spec = selectRouteSpec(
    matches,
    accessTokenPresent = ctx.accessTokenPresent or ctx.appserviceAuthenticated,
    federationAuthenticated = ctx.federationAuthenticated,
  )
  let decision = checkRouteAuthorization(spec, ctx)
  if not decision.allowed:
    return matrixErrorResponse(401, "M_UNAUTHORIZED", decision.reason, spec.name, spec.kind)

  let runtimeResult = dispatchRoute(
    spec.name,
    accessTokenPresent = ctx.accessTokenPresent or ctx.appserviceAuthenticated,
    federationAuthenticated = ctx.federationAuthenticated,
  )
  if not runtimeResult.ok:
    return routeErrorToResponse(runtimeResult.routeName, runtimeResult.routeKind, runtimeResult.error)

  let routeArgs = extractRouteArgs(req)
  if spec.name in handlers:
    return handlers[spec.name](state, req, spec, routeArgs, ctx)
  genericImplementedHandler(state, req, spec, routeArgs, ctx)
