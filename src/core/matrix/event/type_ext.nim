## Event type extension helpers.
##
## Ported from Rust core/matrix/event/type_ext.rs — provides a
## convenience proc for pairing an event type with a state key
## to create a TypeStateKey for use in state maps.

import ../event
import state_key

const
  RustPath* = "core/matrix/event/type_ext.rs"
  RustCrate* = "core"

proc withStateKey*(eventType: StateEventType;
                   stateKey: string): TypeStateKey =
  ## Create a TypeStateKey from an event type and state key.
  makeTypeStateKey(eventType, stateKey)

proc withStateKey*(eventType: TimelineEventType;
                   stateKey: string): TypeStateKey =
  ## Create a TypeStateKey from a timeline event type and state key.
  ## Timeline event types are converted to state event types.
  makeTypeStateKey(StateEventType(eventType), stateKey)
