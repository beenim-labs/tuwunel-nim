## State key type and utilities.
##
## Ported from Rust core/matrix/event/state_key.rs — defines the
## TypeStateKey tuple type used for state map keys.


import ../event

const
  RustPath* = "core/matrix/event/state_key.rs"
  RustCrate* = "core"

type
  ## A state key string.
  StateKey* = string

  ## Composite key for state maps: (event_type, state_key).
  TypeStateKey* = tuple[eventType: StateEventType, stateKey: StateKey]

proc cmpTypeStateKey*(a, b: TypeStateKey): int =
  ## Compare two TypeStateKey values (for sorting).
  result = cmp(a.eventType, b.eventType)
  if result == 0:
    result = cmp(a.stateKey, b.stateKey)

proc rcmpTypeStateKey*(a, b: TypeStateKey): int =
  ## Reverse compare two TypeStateKey values.
  result = cmp(b.eventType, a.eventType)
  if result == 0:
    result = cmp(b.stateKey, a.stateKey)

proc makeTypeStateKey*(eventType: StateEventType;
                       stateKey: StateKey): TypeStateKey =
  ## Create a TypeStateKey from event type and state key.
  (eventType: eventType, stateKey: stateKey)
