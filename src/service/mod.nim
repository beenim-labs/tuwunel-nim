## service/mod — service module.
##
## Ported from Rust service/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/mod.rs"
  RustCrate* = "service"

type Service* = ref object
  ## service service.
  discard

# import ./services
# import ./account_data
# import ./admin
# import ./appservice
# import ./client
# import ./config
# import ./deactivate
# import ./emergency
# import ./federation
# import ./globals
# import ./key_backups
# import ./media
# import ./membership
# import ./oauth
# import ./presence
# import ./pusher
# import ./registration_tokens
# import ./resolver
# import ./rooms
# import ./sending
# import ./server_keys
# import ./sync
# import ./transaction_ids
# import ./uiaa
# import ./users

proc init*() = discard