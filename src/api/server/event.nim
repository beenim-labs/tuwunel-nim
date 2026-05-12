const
  RustPath* = "api/server/event.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

proc eventPayload*(
    origin: string;
    originServerTs: int64;
    pdu: JsonNode
): tuple[ok: bool, payload: JsonNode] =
  if origin.strip().len == 0 or pdu.isNil or pdu.kind != JObject:
    return (false, newJObject())

  (true, %*{
    "origin": origin,
    "origin_server_ts": originServerTs,
    "pdu": pdu
  })
