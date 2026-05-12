const
  RustPath* = "api/client/thirdparty.rs"
  RustCrate* = "api"

import std/json

proc thirdPartyProtocolsPayload*(): JsonNode =
  newJObject()

proc getProtocolsResponse*(): JsonNode =
  %*{"protocols": thirdPartyProtocolsPayload()}
