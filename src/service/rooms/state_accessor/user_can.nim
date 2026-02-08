## state_accessor/user_can — service module.
##
## Ported from Rust service/rooms/state_accessor/user_can.rs
##
## Permission checking: whether a user can redact events, see events
## based on history visibility, invite other users, or tombstone rooms.

import std/[options, json, tables, strutils, logging]

const
  RustPath* = "service/rooms/state_accessor/user_can.rs"
  RustCrate* = "service"

type
  HistoryVisibility* = enum
    hvWorldReadable = "world_readable"
    hvShared = "shared"
    hvInvited = "invited"
    hvJoined = "joined"

proc userCanRedact*(self: Service; redacts: string; sender: string;
                    roomId: string; federation: bool): bool =
  ## Ported from `user_can_redact`.
  ##
  ## Checks if a given user can redact a given event.
  ## If federation is true, allows redaction by any user from the same
  ## server as the original event sender.

  # Fetch the event being redacted
  # In real impl: self.services.timeline.getPdu(redacts)
  let redactingEvent = none(JsonNode)  # placeholder

  # Forbid redacting m.room.create
  if redactingEvent.isSome:
    let eventType = redactingEvent.get().getOrDefault("type").getStr("")
    if eventType == "m.room.create":
      raise newException(ValueError, "Redacting m.room.create is not safe, forbidding.")
    if eventType == "m.room.server_acl":
      raise newException(ValueError,
        "Redacting m.room.server_acl will result in the room being inaccessible " &
        "for everyone (empty allow key), forbidding.")

  # Check power levels
  # In real impl: self.getPowerLevels(roomId)
  let powerLevels = none(JsonNode)  # placeholder

  if powerLevels.isSome:
    let pl = powerLevels.get()
    # In real impl: check userCanRedactEventOfOther(sender, pl)
    # || userCanRedactOwnEvent(sender, pl) && senderMatch
    let canRedactOther = false  # placeholder: check power level
    let canRedactOwn = false    # placeholder: check power level

    if canRedactOther:
      return true

    if canRedactOwn and redactingEvent.isSome:
      let eventSender = redactingEvent.get().getOrDefault("sender").getStr("")
      if federation:
        # For federation: same server is enough
        let senderServer = sender.split(':')[^1]
        let eventServer = eventSender.split(':')[^1]
        return senderServer == eventServer
      else:
        return eventSender == sender

    return false
  else:
    # Fallback: check m.room.create
    # In real impl: self.roomStateGet(roomId, "m.room.create", "")
    let createEvent = none(JsonNode)  # placeholder
    if createEvent.isSome:
      let creator = createEvent.get().getOrDefault("sender").getStr("")
      return creator == sender or
        (redactingEvent.isSome and
         redactingEvent.get().getOrDefault("sender").getStr("") == sender)
    else:
      raise newException(ValueError,
        "No m.room.power_levels or m.room.create events in database for room")


proc userCanSeeEvent*(self: Service; userId, roomId, eventId: string): bool =
  ## Ported from `user_can_see_event`.
  ##
  ## Whether a user is allowed to see an event, based on
  ## the room's history_visibility at that event's state.

  # Get state hash at event
  # In real impl: self.services.state.pduShortstatehash(eventId)
  let shortstatehash = none(uint64)  # placeholder
  if shortstatehash.isNone:
    return true  # if we don't know the state, allow access

  # Get history visibility from state
  # In real impl: self.stateGetContent(shortstatehash, "m.room.history_visibility", "")
  let historyVisibility = hvShared  # placeholder default

  case historyVisibility
  of hvWorldReadable:
    return true
  of hvInvited:
    # Allow if user was at least invited at this state
    # In real impl: self.userWasInvited(shortstatehash.get(), userId)
    return false  # placeholder
  of hvJoined:
    # Allow only if user was joined at this state
    # In real impl: self.userWasJoined(shortstatehash.get(), userId)
    return false  # placeholder
  of hvShared:
    # Allow if user is currently joined
    # In real impl: self.services.stateCache.isJoined(userId, roomId)
    return false  # placeholder


proc userCanSeeStateEvents*(self: Service; userId, roomId: string): bool =
  ## Ported from `user_can_see_state_events`.
  ##
  ## Whether a user is allowed to see state events based on
  ## the room's current history_visibility.

  # If currently joined, always allow
  # In real impl: self.services.stateCache.isJoined(userId, roomId)
  let isJoined = false  # placeholder
  if isJoined:
    return true

  # Get current history visibility
  # In real impl: self.roomStateGetContent(roomId, "m.room.history_visibility", "")
  let historyVisibility = hvShared  # placeholder default

  case historyVisibility
  of hvWorldReadable:
    return true
  of hvInvited:
    # In real impl: self.services.stateCache.isInvited(userId, roomId)
    return false
  of hvShared:
    # In real impl: self.services.stateCache.onceJoined(userId, roomId)
    return false
  of hvJoined:
    return false


proc userCanInvite*(self: Service; roomId, sender, targetUser: string): bool =
  ## Ported from `user_can_invite`.
  ##
  ## Whether the sender can invite the target user to the room.
  ## Checks by attempting to create and sign an invite event.

  # In real impl: self.services.timeline.createHashAndSignEvent(
  #   PduBuilder.state(targetUser, MembershipState.Invite), sender, roomId, stateLock)
  # For now: check power levels
  false  # placeholder


proc userCanTombstone*(self: Service; roomId, userId: string): bool =
  ## Ported from `user_can_tombstone`.
  ##
  ## Whether the user can send a tombstone event to replace the room.

  # Must be joined first
  # In real impl: self.services.stateCache.isJoined(userId, roomId)
  let isJoined = false  # placeholder
  if not isJoined:
    return false

  # In real impl: try to create and sign a tombstone event
  false  # placeholder
