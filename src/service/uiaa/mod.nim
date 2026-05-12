const
  RustPath* = "service/uiaa/mod.rs"
  RustCrate* = "service"
  SessionIdLength* = 32

import std/[json, random, strutils, tables]

type
  UiaaInfo* = object
    session*: string
    flows*: seq[seq[string]]
    completed*: seq[string]
    authErrorKind*: string
    authErrorMessage*: string

  UiaaFetchResult* = tuple[ok: bool, info: UiaaInfo, err: string]
  UiaaLookupResult* = tuple[ok: bool, userId: string, deviceId: string, info: UiaaInfo]
  UiaaAuthResult* = tuple[ok: bool, completed: bool, info: UiaaInfo, err: string]

  UiaaStore* = object
    requests*: Table[string, JsonNode]
    sessions*: Table[string, UiaaInfo]

var randomized = false

proc ensureRandomized() =
  if not randomized:
    randomize()
    randomized = true

proc randomSessionString(length: int): string =
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  ensureRandomized()
  result = newString(max(length, 0))
  for idx in 0 ..< result.len:
    result[idx] = alphabet[rand(alphabet.high)]

proc initUiaaStore*(): UiaaStore =
  UiaaStore(requests: initTable[string, JsonNode](), sessions: initTable[string, UiaaInfo]())

proc initUiaaInfo*(flows: openArray[seq[string]]; session = ""): UiaaInfo =
  result = UiaaInfo(session: session, flows: @[], completed: @[])
  for flow in flows:
    result.flows.add(flow)

proc uiaaKey*(userId, deviceId, session: string): string =
  userId & "\0" & deviceId & "\0" & session

proc setAuthError(info: var UiaaInfo; kind, message: string) =
  info.authErrorKind = kind
  info.authErrorMessage = message

proc hasCompleted(info: UiaaInfo; stage: string): bool =
  for completed in info.completed:
    if completed == stage:
      return true
  false

proc addCompleted*(info: var UiaaInfo; stage: string) =
  if not info.hasCompleted(stage):
    info.completed.add(stage)

proc flowSatisfied(info: UiaaInfo): bool =
  for flow in info.flows:
    var complete = true
    for stage in flow:
      if not info.hasCompleted(stage):
        complete = false
        break
    if complete:
      return true
  false

proc updateUiaaSession*(
  store: var UiaaStore;
  userId, deviceId, session: string;
  info: UiaaInfo;
  present = true;
) =
  let key = uiaaKey(userId, deviceId, session)
  if present:
    store.sessions[key] = info
  else:
    store.sessions.del(key)

proc create*(
  store: var UiaaStore;
  userId, deviceId: string;
  info: UiaaInfo;
  jsonBody: JsonNode;
): UiaaInfo =
  result = info
  if result.session.len == 0:
    result.session = randomSessionString(SessionIdLength)
  let key = uiaaKey(userId, deviceId, result.session)
  store.requests[key] = if jsonBody.isNil: newJObject() else: jsonBody.copy()
  store.updateUiaaSession(userId, deviceId, result.session, result)

proc getUiaaRequest*(
  store: UiaaStore;
  userId, deviceId, session: string;
): JsonNode =
  let key = uiaaKey(userId, deviceId, session)
  if key notin store.requests:
    return nil
  store.requests[key].copy()

proc getUiaaSession*(
  store: UiaaStore;
  userId, deviceId, session: string;
): UiaaFetchResult =
  let key = uiaaKey(userId, deviceId, session)
  if key notin store.sessions:
    return (false, UiaaInfo(), "UIAA session does not exist.")
  (true, store.sessions[key], "")

proc getUiaaSessionBySessionId*(store: UiaaStore; sessionId: string): UiaaLookupResult =
  for key, info in store.sessions:
    if info.session != sessionId:
      continue
    let first = key.find('\0')
    let second = key.find('\0', first + 1)
    if first < 0 or second < 0:
      continue
    return (
      true,
      key[0 ..< first],
      key[first + 1 ..< second],
      info,
    )
  (false, "", "", UiaaInfo())

proc tryAuth*(
  store: var UiaaStore;
  userId, deviceId: string;
  authType: string;
  baseInfo: UiaaInfo;
  session = "";
  identifierUser = "";
  passwordOk = false;
  registrationTokenOk = false;
  oauthApproved = false;
): UiaaAuthResult =
  var info: UiaaInfo
  if session.len > 0:
    let existing = store.getUiaaSession(userId, deviceId, session)
    if not existing.ok:
      return (false, false, UiaaInfo(), existing.err)
    info = existing.info
  else:
    info = baseInfo

  if info.session.len == 0:
    info.session = randomSessionString(SessionIdLength)

  case authType
  of "m.login.password":
    if identifierUser.len > 0 and identifierUser != userId:
      return (false, false, info, "User ID and access token mismatch.")
    if not passwordOk:
      info.setAuthError("M_FORBIDDEN", "Invalid username or password.")
      return (true, false, info, "")
    info.addCompleted("m.login.password")
  of "m.login.registration_token":
    if not registrationTokenOk:
      info.setAuthError("M_FORBIDDEN", "Invalid registration token.")
      return (true, false, info, "")
    info.addCompleted("m.login.registration_token")
  of "m.login.sso.fallback":
    if not info.hasCompleted("m.login.sso"):
      info.setAuthError("M_FORBIDDEN", "SSO authentication not completed for this session.")
      return (true, false, info, "")
  of "org.matrix.login.oauth2":
    if not info.hasCompleted("org.matrix.login.oauth2"):
      if oauthApproved:
        info.addCompleted("org.matrix.login.oauth2")
      else:
        info.setAuthError("M_FORBIDDEN", "OAuth cross-signing reset not approved for this session.")
        return (true, false, info, "")
  of "m.login.dummy":
    info.addCompleted("m.login.dummy")
  else:
    discard

  if info.flowSatisfied():
    store.updateUiaaSession(userId, deviceId, info.session, info, present = false)
    return (true, true, info, "")

  store.updateUiaaSession(userId, deviceId, info.session, info)
  (true, false, info, "")
