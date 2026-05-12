import std/json

const
  RustPath* = "api/server/openid.rs"
  RustCrate* = "api"

proc openIdUserInfoPayload*(
    userId: string
): tuple[ok: bool, payload: JsonNode] =
  if userId.len == 0:
    return (false, newJObject())
  (true, %*{"sub": userId})
