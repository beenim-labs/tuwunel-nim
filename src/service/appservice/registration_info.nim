## appservice/registration_info — service module.
##
## Ported from Rust service/appservice/registration_info.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/appservice/registration_info.rs"
  RustCrate* = "service"

type
  RegistrationInfo* = ref object
    registration*: Registration
    users*: NamespaceRegex
    aliases*: NamespaceRegex
    rooms*: NamespaceRegex

proc isUserMatch*(self: RegistrationInfo; userId: string): bool =
  ## Ported from `is_user_match`.
  false

proc isExclusiveUserMatch*(self: RegistrationInfo; userId: string): bool =
  ## Ported from `is_exclusive_user_match`.
  false

proc tryFrom*(value: Registration) =
  ## Ported from `try_from`.
  discard
