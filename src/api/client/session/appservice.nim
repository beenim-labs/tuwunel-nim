const
  RustPath* = "api/client/session/appservice.rs"
  RustCrate* = "api"

import std/json

import api/client/session/password

type
  AppserviceLoginResult* = tuple[ok: bool, userId: string, errcode: string, message: string]

proc appserviceLoginUserIdFromBody*(
  body: JsonNode;
  fallbackUserId, serverName: string
): string =
  if not body.isNil and body.kind == JObject:
    let identifierUser = body{"identifier"}{"user"}.getStr("")
    if identifierUser.len > 0:
      let parsed = userIdWithServer(identifierUser, serverName)
      return if parsed.ok: parsed.userId else: identifierUser
    let legacyUser = body{"user"}.getStr("")
    if legacyUser.len > 0:
      let parsed = userIdWithServer(legacyUser, serverName)
      return if parsed.ok: parsed.userId else: legacyUser
  fallbackUserId

proc appserviceLoginPolicy*(
  userId, serverName: string;
  appserviceTokenPresent, namespaceMatches, userExists: bool;
  emergencyModeEnabled = false;
): AppserviceLoginResult =
  if not appserviceTokenPresent:
    return (false, "", "M_MISSING_TOKEN", "Missing appservice token.")
  let parsed = userIdWithServer(userId, serverName)
  if not parsed.ok:
    return (false, "", parsed.errcode, parsed.message)
  if not namespaceMatches and not emergencyModeEnabled:
    return (false, "", "M_EXCLUSIVE", "Username is not in an appservice namespace.")
  if not userExists:
    return (false, "", "M_INVALID_PARAM", "User does not exist.")
  (true, parsed.userId, "", "")
