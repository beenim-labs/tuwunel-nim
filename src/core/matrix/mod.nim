## Core Matrix Library — module re-exports.
##
## Ported from Rust core/matrix/mod.rs — provides a unified import
## point for all Matrix types.

import event as event_mod
import pdu/builder as builder_mod
import pdu/count as count_mod
import pdu/hashes as hashes_mod
import pdu/id as id_mod
import event/state_key as state_key_mod
import event/type_ext as type_ext_mod

const
  RustPath* = "core/matrix/mod.rs"
  RustCrate* = "core"

# Re-export core event types
export event_mod

# Re-export PDU types
export builder_mod
export count_mod
export hashes_mod
export id_mod

# Re-export state key types
export state_key_mod
export type_ext_mod

# Short ID type aliases (matching Rust)
type
  ShortId* = uint64
  ShortStateKey* = ShortId
  ShortEventId* = ShortId
