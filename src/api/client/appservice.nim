const
  RustPath* = "api/client/appservice.rs"
  RustCrate* = "api"

import std/[json, strutils]

type
  AppservicePingPolicyResult* = tuple[ok: bool, errcode: string, message: string, reason: string]

proc pingResponse*(durationMs = 0): JsonNode =
  %*{"duration_ms": durationMs}

proc pingPolicy*(
  registrationId: string;
  knownRegistrationIds: openArray[string];
  accessToken, expectedAccessToken: string;
): AppservicePingPolicyResult =
  let normalizedId = registrationId.strip()
  if normalizedId.len == 0:
    return (false, "M_NOT_FOUND", "Unknown appservice.", "missing_registration_id")
  var known = false
  for candidate in knownRegistrationIds:
    if candidate == normalizedId:
      known = true
      break
  if not known:
    return (false, "M_NOT_FOUND", "Unknown appservice.", "unknown_registration")
  let token = accessToken.strip()
  if token.len == 0:
    return (false, "M_MISSING_TOKEN", "Missing access token.", "missing_access_token")
  if token != expectedAccessToken:
    return (false, "M_UNKNOWN_TOKEN", "Unknown access token.", "invalid_access_token")
  (true, "", "", "")
