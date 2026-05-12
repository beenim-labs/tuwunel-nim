const
  RustPath* = "api/client/capabilities.rs"
  RustCrate* = "api"

import std/json

import core/config_values
import core/matrix/room_version

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

proc getConfigBool(cfg: FlatConfig; keys: openArray[string]; fallback: bool): bool =
  let value = getConfigValue(cfg, keys)
  case value.kind
  of cvBool:
    value.b
  of cvString:
    case value.s
    of "1", "true", "yes", "on":
      true
    of "0", "false", "no", "off":
      false
    else:
      fallback
  of cvInt:
    value.i != 0
  else:
    fallback

proc roomVersionsCapability*(
  defaultRoomVersion = "11";
  allowUnstableRoomVersions = true;
  allowExperimentalRoomVersions = false;
): JsonNode =
  var available = newJObject()
  for item in supportedRoomVersions(allowUnstableRoomVersions, allowExperimentalRoomVersions):
    available[item.version] = %item.stability
  %*{
    "default": defaultRoomVersion,
    "available": available
  }

proc capabilitiesPayload*(cfg: FlatConfig; isAdmin = false): JsonNode =
  let defaultRoomVersion = getConfigString(
    cfg,
    ["default_room_version", "global.default_room_version"],
    "11",
  )
  let allowUnstable = getConfigBool(
    cfg,
    ["allow_unstable_room_versions", "global.allow_unstable_room_versions"],
    true,
  )
  let allowExperimental = getConfigBool(
    cfg,
    ["allow_experimental_room_versions", "global.allow_experimental_room_versions"],
    false,
  )
  let loginViaExistingSession = getConfigBool(
    cfg,
    ["login_via_existing_session", "global.login_via_existing_session"],
    true,
  )
  let loginWithPassword = getConfigBool(
    cfg,
    ["login_with_password", "global.login_with_password"],
    true,
  )
  let forgetForcedUponLeave = getConfigBool(
    cfg,
    ["forget_forced_upon_leave", "global.forget_forced_upon_leave"],
    false,
  )

  result = %*{
    "capabilities": {
      "m.change_password": {"enabled": loginWithPassword},
      "m.room_versions": roomVersionsCapability(defaultRoomVersion, allowUnstable, allowExperimental),
      "m.set_displayname": {"enabled": true},
      "m.set_avatar_url": {"enabled": true},
      "m.3pid_changes": {"enabled": false},
      "m.get_login_token": {"enabled": loginViaExistingSession},
      "m.profile_fields": {"enabled": true},
      "org.matrix.msc4267.forget_forced_upon_leave": {"enabled": forgetForcedUponLeave}
    }
  }
  if isAdmin:
    result["capabilities"]["m.account_moderation"] = %*{
      "suspend": true,
      "lock": true
    }

proc capabilitiesPayload*(isAdmin = false): JsonNode =
  capabilitiesPayload(initFlatConfig(), isAdmin)
