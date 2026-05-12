const
  RustPath* = "core/matrix/event/type_ext.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import core/matrix/event/state_key

proc withStateKey*(eventType, stateKeyValue: string): TypeStateKey =
  typeStateKey(eventType, stateKeyValue)

proc withEmptyStateKey*(eventType: string): TypeStateKey =
  typeStateKey(eventType, "")
