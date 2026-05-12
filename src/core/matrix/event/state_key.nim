const
  RustPath* = "core/matrix/event/state_key.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

type
  StateKey* = string
  TypeStateKey* = tuple[eventType: string, stateKey: StateKey]

proc typeStateKey*(eventType, stateKey: string): TypeStateKey =
  (eventType, stateKey)

proc cmp*(a, b: TypeStateKey): int =
  result = system.cmp(a.eventType, b.eventType)
  if result == 0:
    result = system.cmp(a.stateKey, b.stateKey)

proc rcmp*(a, b: TypeStateKey): int =
  cmp(b, a)
