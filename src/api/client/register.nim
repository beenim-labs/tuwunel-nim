## client/register — api module.
##
## Ported from Rust api/client/register.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/register.rs"
  RustCrate* = "api"

proc getRegisterAvailableRoute*() =
  ## Ported from `get_register_available_route`.
  discard

proc registerRoute*() =
  ## Ported from `register_route`.
  discard

proc checkRegistrationTokenValidity*() =
  ## Ported from `check_registration_token_validity`.
  discard
