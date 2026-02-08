## server/make_leave — api module.
##
## Ported from Rust api/server/make_leave.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/make_leave.rs"
  RustCrate* = "api"

proc createLeaveEventTemplateRoute*() =
  ## Ported from `create_leave_event_template_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.