const
  RustPath* = "api/client/well_known.rs"
  RustCrate* = "api"

import std/[json, strutils]

import core/config_values
import api/client/rtc

type
  WellKnownResult* = tuple[ok: bool, payload: JsonNode]

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

proc wellKnownClientPayload*(cfg: FlatConfig): WellKnownResult =
  let baseUrl = getConfigString(
    cfg,
    ["well_known.client", "global.well_known.client", "well_known_client"],
    "",
  ).strip()
  if baseUrl.len == 0:
    return (false, newJObject())

  result = (true, %*{
    "m.homeserver": {
      "base_url": baseUrl
    }
  })
  let rtcFoci = rtcTransports(cfg)
  if rtcFoci.len > 0:
    result.payload["org.matrix.msc4143.rtc_foci"] = %rtcFoci

proc wellKnownSupportPayload*(cfg: FlatConfig): WellKnownResult =
  let supportPage = getConfigString(
    cfg,
    ["well_known.support_page", "global.well_known.support_page", "support_page", "global.support_page"],
    "",
  ).strip()
  let role = getConfigString(
    cfg,
    ["well_known.support_role", "global.well_known.support_role", "support_role", "global.support_role"],
    "",
  ).strip()
  let email = getConfigString(
    cfg,
    ["well_known.support_email", "global.well_known.support_email", "support_email", "global.support_email"],
    "",
  ).strip()
  let mxid = getConfigString(
    cfg,
    ["well_known.support_mxid", "global.well_known.support_mxid", "support_mxid", "global.support_mxid"],
    "",
  ).strip()

  if supportPage.len == 0 and role.len == 0:
    return (false, newJObject())
  if role.len > 0 and email.len == 0 and mxid.len == 0:
    return (false, newJObject())

  var contacts = newJArray()
  if role.len > 0:
    var contact = %*{"role": role}
    if email.len > 0:
      contact["email_address"] = %email
    if mxid.len > 0:
      contact["matrix_id"] = %mxid
    contacts.add(contact)

  if contacts.len == 0 and supportPage.len == 0:
    return (false, newJObject())

  var payload = %*{"contacts": contacts}
  if supportPage.len > 0:
    payload["support_page"] = %supportPage
  (true, payload)
