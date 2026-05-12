const
  RustPath* = "api/client/session/password.rs"
  RustCrate* = "api"

import std/[json, strutils]

type
  LoginUserResult* = tuple[
    ok: bool,
    userId: string,
    lowercasedUserId: string,
    errcode: string,
    message: string
  ]

proc serverNameFromUserId*(userId: string): string =
  let colon = userId.rfind(':')
  if colon < 0:
    ""
  else:
    userId[colon + 1 .. ^1]

proc localpartFromUserId*(userId: string): string =
  if userId.len == 0:
    return ""
  let colon = userId.rfind(':')
  let start = if userId[0] == '@': 1 else: 0
  if colon < 0 or colon <= start:
    userId[start .. ^1]
  else:
    userId[start ..< colon]

proc userIdWithServer*(raw, serverName: string): LoginUserResult =
  let cleaned = raw.strip()
  if cleaned.len == 0:
    return (false, "", "", "M_UNKNOWN", "Valid identifier or username was not provided (invalid or unsupported login type?)")

  let userId =
    if cleaned.startsWith("@"):
      cleaned
    else:
      "@" & cleaned & ":" & serverName

  if not userId.startsWith("@") or userId.rfind(':') <= 1:
    return (false, "", "", "M_INVALID_USERNAME", "Username is invalid.")
  if serverNameFromUserId(userId) != serverName:
    return (false, "", "", "M_UNKNOWN", "User ID does not belong to this homeserver")

  let lower = "@" & localpartFromUserId(userId).toLowerAscii() & ":" & serverName
  (true, userId, lower, "", "")

proc passwordLoginUser*(body: JsonNode; serverName: string): LoginUserResult =
  if body.isNil or body.kind != JObject:
    return (false, "", "", "M_UNKNOWN", "Valid identifier or username was not provided (invalid or unsupported login type?)")
  let identifierUser = body{"identifier"}{"user"}.getStr("")
  let legacyUser = body{"user"}.getStr("")
  let raw =
    if identifierUser.len > 0:
      identifierUser
    else:
      legacyUser
  userIdWithServer(raw, serverName)

proc passwordLoginPolicy*(
  accountOrigin = "password";
  hashPresent = true;
  hashEmpty = false;
  passwordMatches = true;
): tuple[ok: bool, errcode: string, message: string] =
  if accountOrigin.len > 0 and accountOrigin != "password":
    return (false, "M_FORBIDDEN", "Account does not permit password login.")
  if not hashPresent or not passwordMatches:
    return (false, "M_FORBIDDEN", "Wrong username or password.")
  if hashEmpty:
    return (false, "M_USER_DEACTIVATED", "The user has been deactivated")
  (true, "", "")
