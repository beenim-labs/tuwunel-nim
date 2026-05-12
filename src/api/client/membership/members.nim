const
  RustPath* = "api/client/membership/members.rs"
  RustCrate* = "api"

import std/json

type
  MembersPolicyResult* = tuple[ok: bool, errcode: string, message: string]

proc memberEventMatches*(currentMembership, membershipFilter, notMembershipFilter: string): bool =
  if membershipFilter.len > 0 and currentMembership != membershipFilter:
    return false
  if notMembershipFilter.len > 0 and currentMembership == notMembershipFilter:
    return false
  true

proc memberEventsResponse*(chunk: JsonNode): JsonNode =
  %*{"chunk": if chunk.isNil: newJArray() else: chunk.copy()}

proc joinedMemberProfile*(displayName = ""; avatarUrl = ""): JsonNode =
  %*{
    "display_name": displayName,
    "avatar_url": avatarUrl,
  }

proc joinedMembersResponse*(joined: JsonNode): JsonNode =
  %*{"joined": if joined.isNil: newJObject() else: joined.copy()}

proc memberEventsAccessPolicy*(roomExists: bool; canSeeStateEvents: bool): MembersPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canSeeStateEvents:
    return (
      false,
      "M_FORBIDDEN",
      "You aren't a member of the room and weren't previously a member of the room.",
    )
  (true, "", "")

proc joinedMembersAccessPolicy*(roomExists: bool; canSeeJoinedMembers: bool): MembersPolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not canSeeJoinedMembers:
    return (false, "M_FORBIDDEN", "You aren't a member of the room.")
  (true, "", "")
