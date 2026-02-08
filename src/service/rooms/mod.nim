## rooms/mod — service module.
##
## Ported from Rust service/rooms/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/mod.rs"
  RustCrate* = "service"

type Service* = ref object
  ## rooms service.
  discard

# import ./alias
# import ./auth_chain
# import ./delete
# import ./directory
# import ./event_handler
# import ./lazy_loading
# import ./metadata
# import ./pdu_metadata
# import ./read_receipt
# import ./retention
# import ./search
# import ./short
# import ./spaces
# import ./state
# import ./state_accessor
# import ./state_cache
# import ./state_compressor
# import ./threads
# import ./timeline
# import ./typing

proc init*() = discard