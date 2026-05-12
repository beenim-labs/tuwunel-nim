import std/[json, strutils]

const
  RustPath* = "api/server/well_known.rs"
  RustCrate* = "api"

proc wellKnownServerPayload*(
    serverName: string
): tuple[ok: bool, payload: JsonNode] =
  let server = serverName.strip()
  if server.len == 0:
    return (false, newJObject())
  (true, %*{"m.server": server})
