## membership/members — api module.
##
## Ported from Rust api/client/membership/members.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/membership/members.rs"
  RustCrate* = "api"

proc getMemberEventsRoute*() =
  ## Ported from `get_member_events_route`.
  discard

proc joinedMembersRoute*() =
  ## Ported from `joined_members_route`.
  discard
