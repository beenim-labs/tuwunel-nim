const
  RustPath* = "api/client/membership/invite.rs"
  RustCrate* = "api"

import std/json

type
  InvitePolicyResult* = tuple[ok: bool, errcode: string, message: string]

  InviteRequest* = object
    userId*: string
    reason*: string

proc inviteMembership*(): string =
  "invite"

proc inviteResponse*(): JsonNode =
  newJObject()

proc parseInviteRequest*(body: JsonNode): tuple[ok: bool, request: InviteRequest, errcode: string, message: string] =
  if body.isNil or body.kind != JObject:
    return (false, InviteRequest(), "M_BAD_JSON", "Invalid JSON body.")

  let userId = body{"user_id"}.getStr("")
  if userId.len > 0:
    return (
      true,
      InviteRequest(userId: userId, reason: body{"reason"}.getStr("")),
      "",
      "",
    )

  if body.hasKey("id_server") or body.hasKey("medium") or body.hasKey("address"):
    return (
      false,
      InviteRequest(),
      "M_THREEPID_DENIED",
      "Third party identifiers are not implemented",
    )

  (false, InviteRequest(), "M_BAD_JSON", "user_id is required.")

proc invitePolicy*(
  roomExists: bool;
  senderCanInvite: bool;
  targetBanned = false;
  senderIgnoredRecipient = false;
  recipientIgnoredBySender = false;
): InvitePolicyResult =
  if not roomExists:
    return (false, "M_NOT_FOUND", "Room not found.")
  if not senderCanInvite:
    return (false, "M_FORBIDDEN", "You aren't a member of the room.")
  if targetBanned:
    return (false, "M_FORBIDDEN", "User is banned from this room.")
  if senderIgnoredRecipient or recipientIgnoredBySender:
    return (true, "", "")
  (true, "", "")
