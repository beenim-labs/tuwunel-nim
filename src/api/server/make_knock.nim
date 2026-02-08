## server/make_knock — api module.
##
## Ported from Rust api/server/make_knock.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/server/make_knock.rs"
  RustCrate* = "api"

proc createKnockEventTemplateRoute*() =
  ## Ported from `create_knock_event_template_route`.
  discard

## This module's Rust source has minimal public API.
## Service integration happens through the database layer.