const
  RustPath* = "api/client/register.rs"
  RustCrate* = "api"

import std/[json, options, strutils]

type
  RegisterPolicyResult* = tuple[ok: bool, errcode: string, message: string]
  RegisterAvailabilityResult* = tuple[
    ok: bool,
    userId: string,
    username: string,
    errcode: string,
    message: string
  ]

proc localpartFromUserId*(userId: string): string =
  if userId.len < 4 or userId[0] != '@':
    return ""
  let sep = userId.find(':')
  if sep <= 1:
    return ""
  userId[1 ..< sep]

proc serverNameFromUserId*(userId: string): string =
  let sep = userId.find(':')
  if sep < 0 or sep >= userId.high:
    return ""
  userId[(sep + 1) .. ^1]

proc isMatrixAppserviceIrc*(registrationId: string): bool =
  registrationId == "irc" or
    registrationId.contains("matrix-appservice-irc") or
    registrationId.contains("matrix_appservice_irc")

proc isValidMatrixLocalpart*(localpart: string; relaxed = false): bool =
  if localpart.len == 0:
    return false
  if relaxed:
    return localpart.find(':') < 0
  for ch in localpart:
    if ch in {'a'..'z', '0'..'9', '.', '_', '=', '-', '/'}:
      continue
    return false
  true

proc registrationUserIdFromUsername*(
  rawUsername: string;
  serverName: string;
  preserveCase = false;
  relaxed = false;
): RegisterAvailabilityResult =
  var username = rawUsername.strip()
  if username.len == 0:
    return (false, "", "", "M_INVALID_USERNAME", "Username is not valid.")
  if not preserveCase:
    username = username.toLowerAscii()

  var localpart = username
  if username.startsWith("@"):
    if serverNameFromUserId(username) != serverName:
      return (false, "", "", "M_INVALID_USERNAME", "Username is not valid.")
    localpart = localpartFromUserId(username)
  elif username.find(':') >= 0:
    return (false, "", "", "M_INVALID_USERNAME", "Username is not valid.")

  if not isValidMatrixLocalpart(localpart, relaxed):
    return (false, "", "", "M_INVALID_USERNAME", "Username contains disallowed characters or spaces.")

  (true, "@" & localpart & ":" & serverName, localpart, "", "")

proc registrationAvailability*(
  rawUsername, serverName: string;
  userExists = false;
  appservicePresent = false;
  appserviceMatches = true;
  exclusiveReserved = false;
  forbiddenUsername = false;
  preserveCase = false;
  relaxed = false;
): RegisterAvailabilityResult =
  if forbiddenUsername:
    return (false, "", "", "M_FORBIDDEN", "Username is forbidden")

  let parsed = registrationUserIdFromUsername(rawUsername, serverName, preserveCase, relaxed)
  if not parsed.ok:
    return parsed

  if userExists:
    return (false, parsed.userId, parsed.username, "M_USER_IN_USE", "User ID is not available.")
  if appservicePresent and not appserviceMatches:
    return (false, parsed.userId, parsed.username, "M_EXCLUSIVE", "Username is not in an appservice namespace.")
  if not appservicePresent and exclusiveReserved:
    return (false, parsed.userId, parsed.username, "M_EXCLUSIVE", "Username is reserved by an appservice.")

  parsed

proc registerPolicy*(
  allowRegistration = true;
  isAppservice = false;
  isGuest = false;
  allowGuestRegistration = false;
): RegisterPolicyResult =
  if not allowRegistration and not isAppservice:
    return (false, "M_FORBIDDEN", "Registration has been disabled.")
  if isGuest and not allowGuestRegistration:
    return (false, "M_GUEST_ACCESS_FORBIDDEN", "Guest registration is disabled.")
  (true, "", "")

proc appserviceRegisterPolicy*(
  appserviceTokenPresent, namespaceMatches: bool;
  emergencyModeEnabled = false;
): RegisterPolicyResult =
  if not appserviceTokenPresent:
    return (false, "M_MISSING_TOKEN", "Missing appservice token.")
  if not namespaceMatches and not emergencyModeEnabled:
    return (false, "M_EXCLUSIVE", "Username is not in an appservice namespace.")
  (true, "", "")

proc registerResponse*(
  userId, homeServer: string;
  accessToken = "";
  deviceId = "";
  refreshToken = "";
  expiresInMs: Option[int64] = none(int64)
): JsonNode =
  result = %*{
    "user_id": userId,
    "home_server": homeServer
  }
  if accessToken.len > 0:
    result["access_token"] = %accessToken
  if deviceId.len > 0:
    result["device_id"] = %deviceId
  if refreshToken.len > 0:
    result["refresh_token"] = %refreshToken
  if expiresInMs.isSome:
    result["expires_in_ms"] = %expiresInMs.get()

proc registrationTokenValidityPolicy*(enabled: bool): RegisterPolicyResult =
  if not enabled:
    return (false, "M_FORBIDDEN", "Server does not allow token registration.")
  (true, "", "")

proc registrationTokenValidityPayload*(valid: bool): JsonNode =
  %*{"valid": valid}
