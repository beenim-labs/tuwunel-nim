## users/register — service module.
##
## Ported from Rust service/users/register.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/users/register.rs"
  RustCrate* = "service"

type
  Register* = ref object
    discard

proc fullRegister*(self: Register) =
  ## Ported from `full_register`.
  discard
