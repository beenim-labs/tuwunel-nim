const
  RustPath* = "api/client/session/token.rs"
  RustCrate* = "api"

import std/json

type
  SessionPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc tokenLoginPolicy*(loginViaToken: bool): SessionPolicyResult =
  if not loginViaToken:
    return (false, "M_UNKNOWN", "Token login is not enabled.")
  (true, "", "")

proc loginTokenIssuePolicy*(
  loginViaExistingSession, loginViaToken, userActive: bool
): SessionPolicyResult =
  if not loginViaExistingSession or not loginViaToken:
    return (false, "M_FORBIDDEN", "Login via an existing session is not enabled")
  if not userActive:
    return (false, "M_USER_DEACTIVATED", "This user has been deactivated.")
  (true, "", "")

proc loginTokenPayload*(loginToken: string; expiresInMs: int64): JsonNode =
  %*{
    "login_token": loginToken,
    "expires_in_ms": expiresInMs
  }
