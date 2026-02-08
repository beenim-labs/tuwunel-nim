## client/state — api module.
##
## Ported from Rust api/client/state.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/state.rs"
  RustCrate* = "api"

proc sendStateEventForKeyRoute*() =
  ## Ported from `send_state_event_for_key_route`.
  discard

proc sendStateEventForEmptyKeyRoute*() =
  ## Ported from `send_state_event_for_empty_key_route`.
  discard

proc getStateEventsRoute*() =
  ## Ported from `get_state_events_route`.
  discard

proc getStateEventsForKeyRoute*() =
  ## Ported from `get_state_events_for_key_route`.
  discard

proc getStateEventsForEmptyKeyRoute*() =
  ## Ported from `get_state_events_for_empty_key_route`.
  discard

proc sendStateEventForKeyHelper*(services: Services; sender: string; roomId: string; eventType: StateEventType; json: Raw<AnyStateEventContent>; stateKey: string; timestamp: Option[ruma::MilliSecondsSinceUnixEpoch]): string =
  ## Ported from `send_state_event_for_key_helper`.
  ""

proc allowedToSendStateEvent*(services: Services; roomId: string; eventType: StateEventType; stateKey: string; json: Raw<AnyStateEventContent>) =
  ## Ported from `allowed_to_send_state_event`.
  discard
