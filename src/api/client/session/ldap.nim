const
  RustPath* = "api/client/session/ldap.rs"
  RustCrate* = "api"

import std/strutils

proc ldapBindDn*(bindDn, username: string): tuple[ok: bool, userDn: string, directBind: bool] =
  if bindDn.contains("{username}"):
    return (true, bindDn.replace("{username}", username.toLowerAscii()), true)
  if bindDn.len > 0:
    return (true, bindDn, false)
  (false, "", false)

proc ldapAccountOrigin*(): string =
  "ldap"

proc ldapAdminSyncAction*(
  adminFilterConfigured, isLdapAdmin, isTuwunelAdmin: bool
): string =
  if not adminFilterConfigured:
    return "none"
  if isLdapAdmin and not isTuwunelAdmin:
    return "grant"
  if not isLdapAdmin and isTuwunelAdmin:
    return "revoke"
  "none"
