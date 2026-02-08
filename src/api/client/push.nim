## client/push — api module.
##
## Ported from Rust api/client/push.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/push.rs"
  RustCrate* = "api"

proc getNotificationsRoute*() =
  ## Ported from `get_notifications_route`.
  discard

proc getPushrulesAllRoute*() =
  ## Ported from `get_pushrules_all_route`.
  discard

proc getPushrulesGlobalRoute*() =
  ## Ported from `get_pushrules_global_route`.
  discard

proc getPushruleRoute*() =
  ## Ported from `get_pushrule_route`.
  discard

proc setPushruleRoute*() =
  ## Ported from `set_pushrule_route`.
  discard

proc getPushruleActionsRoute*() =
  ## Ported from `get_pushrule_actions_route`.
  discard

proc setPushruleActionsRoute*() =
  ## Ported from `set_pushrule_actions_route`.
  discard

proc getPushruleEnabledRoute*() =
  ## Ported from `get_pushrule_enabled_route`.
  discard

proc setPushruleEnabledRoute*() =
  ## Ported from `set_pushrule_enabled_route`.
  discard

proc deletePushruleRoute*() =
  ## Ported from `delete_pushrule_route`.
  discard

proc getPushersRoute*() =
  ## Ported from `get_pushers_route`.
  discard

proc setPushersRoute*() =
  ## Ported from `set_pushers_route`.
  discard

proc recreatePushRulesAndReturn*(services: Services; senderUser: ruma::string): get_pushrules_all::v3::Response =
  ## Ported from `recreate_push_rules_and_return`.
  discard
