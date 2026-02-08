## sessions/association — service module.
##
## Ported from Rust service/oauth/sessions/association.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/oauth/sessions/association.rs"
  RustCrate* = "service"

proc setUserAssociationPending*(idpId: string; userId: string; claims: Claims): Option[Claims] =
  ## Ported from `set_user_association_pending`.
  none(Claims)

proc findUserAssociationPending*(idpId: string; userinfo: UserInfo): Option[string] =
  ## Ported from `find_user_association_pending`.
  none(string)

proc removeProviderAssociationsPending*(idpId: string) =
  ## Ported from `remove_provider_associations_pending`.
  discard

proc removeUserAssociationPending*(userId: string; idpId: Option[string]) =
  ## Ported from `remove_user_association_pending`.
  discard

proc isUserAssociationPending*(userId: string): bool =
  ## Ported from `is_user_association_pending`.
  false
