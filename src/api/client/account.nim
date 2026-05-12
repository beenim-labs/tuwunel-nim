const
  RustPath* = "api/client/account.rs"
  RustCrate* = "api"

import std/json

type
  AccountPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc whoamiPayload*(userId, deviceId: string; isGuest = false): JsonNode =
  result = %*{
    "user_id": userId,
    "is_guest": isGuest
  }
  if deviceId.len > 0:
    result["device_id"] = %deviceId

proc changePasswordPolicy*(newPassword: string; authenticated = true): AccountPolicyResult =
  if not authenticated:
    return (false, "M_UNAUTHORIZED", "User-interactive authentication is required.")
  if newPassword.len == 0:
    return (false, "M_INVALID_PARAM", "New password must not be empty.")
  (true, "", "")

proc changePasswordResponse*(): JsonNode =
  newJObject()

proc deactivatePolicy*(authenticated = true): AccountPolicyResult =
  if not authenticated:
    return (false, "M_UNAUTHORIZED", "User-interactive authentication is required.")
  (true, "", "")

proc deactivateResponse*(): JsonNode =
  %*{"id_server_unbind_result": "no-support"}

proc accountThreepidsPayload*(): JsonNode =
  %*{"threepids": []}

proc request3pidManagementTokenPolicy*(): AccountPolicyResult =
  (false, "M_THREEPID_DENIED", "Third party identifiers are not implemented.")
