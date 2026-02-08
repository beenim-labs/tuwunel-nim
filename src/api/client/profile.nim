## client/profile — api module.
##
## Ported from Rust api/client/profile.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/profile.rs"
  RustCrate* = "api"

proc setDisplaynameRoute*() =
  ## Ported from `set_displayname_route`.
  discard

proc getDisplaynameRoute*() =
  ## Ported from `get_displayname_route`.
  discard

proc setAvatarUrlRoute*() =
  ## Ported from `set_avatar_url_route`.
  discard

proc getAvatarUrlRoute*() =
  ## Ported from `get_avatar_url_route`.
  discard

proc getProfileRoute*() =
  ## Ported from `get_profile_route`.
  discard
