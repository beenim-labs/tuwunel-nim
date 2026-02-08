## Module canary — build verification checks.
##
## Ported from Rust core/mods/canary.rs

const
  RustPath* = "core/mods/canary.rs"
  RustCrate* = "core"

proc checkCanary*(): bool =
  ## Verify the module canary is valid. Used to detect ABI mismatches
  ## between dynamically loaded modules and the host binary.
  ## In Nim (statically compiled), this always returns true.
  true

proc canaryValue*(): uint64 =
  ## Return the canary value used for module verification.
  0xDEAD_BEEF_CAFE_BABEu64
