const
  RustPath* = "api/client/session/refresh.rs"
  RustCrate* = "api"

import std/[json, strutils]

type
  RefreshTokenCheck* = tuple[ok: bool, errcode: string, message: string]

proc refreshTokenFormatCheck*(refreshToken: string): RefreshTokenCheck =
  if not refreshToken.startsWith("refresh_"):
    return (false, "M_FORBIDDEN", "Refresh token is malformed.")
  (true, "", "")

proc refreshTokenPayload*(
  accessToken, refreshToken: string;
  expiresInMs: int64
): JsonNode =
  %*{
    "access_token": accessToken,
    "refresh_token": refreshToken,
    "expires_in_ms": expiresInMs
  }
