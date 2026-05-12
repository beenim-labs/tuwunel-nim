const
  RustPath* = "api/client/rtc.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]
import core/config_values

proc configValueItems(value: ConfigValue): seq[ConfigValue] =
  case value.kind
  of cvArray:
    value.items
  else:
    @[value]

proc getConfigValue(cfg: FlatConfig; keys: openArray[string]): ConfigValue =
  for key in keys:
    if key in cfg:
      return cfg[key]
  newNullValue()

proc getConfigString(cfg: FlatConfig; keys: openArray[string]; fallback: string): string =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvString:
    value.s
  of cvInt:
    $value.i
  of cvFloat:
    $value.f
  of cvBool:
    if value.b: "true" else: "false"
  else:
    fallback

proc parseTransport(raw: string): tuple[ok: bool, payload: JsonNode] =
  try:
    let parsed = parseJson(raw)
    if parsed.kind != JObject:
      return (false, newJObject())
    if not parsed.hasKey("type") or parsed["type"].kind != JString or parsed["type"].getStr("").len == 0:
      return (false, newJObject())
    (true, parsed)
  except JsonParsingError:
    (false, newJObject())

proc rtcTransports*(cfg: FlatConfig): seq[JsonNode] =
  result = @[]
  let custom = getConfigValue(cfg, [
    "well_known.rtc_transports",
    "global.well_known.rtc_transports",
    "rtc_transports",
    "global.rtc_transports",
  ])
  if custom.kind != cvNull:
    for item in configValueItems(custom):
      if item.kind != cvString:
        continue
      let parsed = parseTransport(item.s)
      if parsed.ok:
        result.add(parsed.payload)

  let livekitUrl = getConfigString(
    cfg,
    [
      "well_known.livekit_url",
      "global.well_known.livekit_url",
      "livekit_url",
      "global.livekit_url",
    ],
    "",
  ).strip()
  if livekitUrl.len > 0:
    result.add(%*{
      "type": "livekit",
      "livekit_service_url": livekitUrl,
    })

proc rtcTransportsPayload*(cfg: FlatConfig): JsonNode =
  %*{"rtc_transports": rtcTransports(cfg)}
