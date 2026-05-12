const
  RustPath* = "api/client/tuwunel.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

proc tuwunelServerVersionPayload*(
    version: string;
    serverName = "Tuwunel"
): JsonNode =
  %*{
    "name": serverName,
    "version": version,
  }

proc tuwunelLocalUserCountPayload*(count: int): JsonNode =
  %*{"count": count}
