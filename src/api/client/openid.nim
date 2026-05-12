const
  RustPath* = "api/client/openid.rs"
  RustCrate* = "api"

import std/json

type
  OpenIdPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc openIdRequestPolicy*(senderUser, requestedUser: string): OpenIdPolicyResult =
  if senderUser != requestedUser:
    return (
      false,
      "M_INVALID_PARAM",
      "Not allowed to request OpenID tokens on behalf of other users",
    )
  (true, "", "")

proc openIdTokenPayload*(
  accessToken, serverName: string;
  expiresIn = 3600
): JsonNode =
  %*{
    "access_token": accessToken,
    "token_type": "Bearer",
    "matrix_server_name": serverName,
    "expires_in": expiresIn
  }
