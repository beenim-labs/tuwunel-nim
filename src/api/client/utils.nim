const
  RustPath* = "api/client/utils.rs"
  RustCrate* = "api"

import core/config_values

type
  InviteCheckResult* = tuple[ok: bool, errcode: string, message: string]

proc getConfigValue(cfg: FlatConfig; keys: openArray[string]): ConfigValue =
  for key in keys:
    if key in cfg:
      return cfg[key]
  newNullValue()

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

proc inviteCheck*(blockNonAdminInvites, senderIsAdmin: bool): InviteCheckResult =
  if blockNonAdminInvites and not senderIsAdmin:
    return (false, "M_FORBIDDEN", "Invites are not allowed on this server.")
  (true, "", "")

proc inviteCheck*(cfg: FlatConfig; senderIsAdmin: bool): InviteCheckResult =
  inviteCheck(
    getConfigBool(cfg, ["block_non_admin_invites", "global.block_non_admin_invites"], false),
    senderIsAdmin,
  )
