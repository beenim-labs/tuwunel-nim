## oauth/user_info — service module.
##
## Ported from Rust service/oauth/user_info.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/oauth/user_info.rs"
  RustCrate* = "service"

type UserInfo* = ref object
  discard

proc init*() = discard