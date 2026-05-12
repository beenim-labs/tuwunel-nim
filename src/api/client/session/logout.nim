const
  RustPath* = "api/client/session/logout.rs"
  RustCrate* = "api"

import std/json

proc logoutResponse*(): JsonNode =
  newJObject()

proc logoutAllResponse*(): JsonNode =
  newJObject()
