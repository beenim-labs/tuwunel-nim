import std/[json, unittest]

import api/client/membership/ban as client_membership_ban
import api/client/membership/forget as client_membership_forget
import api/client/membership/invite as client_membership_invite
import api/client/membership/join as client_membership_join
import api/client/membership/kick as client_membership_kick
import api/client/membership/knock as client_membership_knock
import api/client/membership/leave as client_membership_leave
import api/client/membership/members as client_membership_members
import api/client/membership/unban as client_membership_unban

suite "Client membership API helpers":
  test "membership response helpers match Matrix client route shapes":
    check client_membership_join.joinedRoomsResponse(["!a:localhost", "", "!b:localhost"])["joined_rooms"].len == 2
    check client_membership_join.joinResponse("!room:localhost")["room_id"].getStr == "!room:localhost"
    check client_membership_knock.knockResponse("!room:localhost")["room_id"].getStr == "!room:localhost"
    check client_membership_leave.leaveResponse().len == 0
    check client_membership_ban.banResponse().len == 0
    check client_membership_kick.kickResponse().len == 0
    check client_membership_unban.unbanResponse().len == 0
    check client_membership_forget.forgetResponse().len == 0

  test "invite parser handles user and rejects unsupported third-party invites":
    let invite = client_membership_invite.parseInviteRequest(%*{
      "user_id": "@alice:localhost",
      "reason": "join us"
    })
    check invite.ok
    check invite.request.userId == "@alice:localhost"
    check invite.request.reason == "join us"

    let thirdParty = client_membership_invite.parseInviteRequest(%*{
      "id_server": "identity.example",
      "medium": "email",
      "address": "a@example.com"
    })
    check not thirdParty.ok
    check thirdParty.errcode == "M_THREEPID_DENIED"

    let missing = client_membership_invite.parseInviteRequest(newJObject())
    check not missing.ok
    check missing.errcode == "M_BAD_JSON"

  test "membership policies preserve Rust route validation details":
    check client_membership_ban.banPolicy("@alice:localhost", "@alice:localhost").errcode == "M_FORBIDDEN"
    check client_membership_kick.kickPolicy("@alice:localhost", "@alice:localhost").message == "You cannot kick yourself."
    check client_membership_unban.unbanPolicy("").errcode == "M_BAD_JSON"
    check client_membership_forget.forgetPolicy(true, "join").message == "You must leave the room before forgetting it"
    check client_membership_forget.forgetPolicy(true, "").message == "No membership event was found, room was never joined"
    check client_membership_forget.forgetPolicy(true, "leave").ok
    check client_membership_forget.forgetPolicy(false, "leave").errcode == "M_NOT_FOUND"
    check client_membership_invite.invitePolicy(roomExists = true, senderCanInvite = false).errcode == "M_FORBIDDEN"
    check client_membership_invite.invitePolicy(roomExists = true, senderCanInvite = true, targetBanned = true).message == "User is banned from this room."

  test "members helpers filter member events and build response payloads":
    check client_membership_members.memberEventMatches("join", "join", "")
    check not client_membership_members.memberEventMatches("leave", "join", "")
    check not client_membership_members.memberEventMatches("ban", "", "ban")

    let memberEvent = %*{"type": "m.room.member", "state_key": "@alice:localhost"}
    let events = client_membership_members.memberEventsResponse(%*[memberEvent])
    check events["chunk"][0]["state_key"].getStr == "@alice:localhost"

    var joined = newJObject()
    joined["@alice:localhost"] = client_membership_members.joinedMemberProfile("Alice", "mxc://localhost/a")
    let payload = client_membership_members.joinedMembersResponse(joined)
    check payload["joined"]["@alice:localhost"]["display_name"].getStr == "Alice"
    check payload["joined"]["@alice:localhost"]["avatar_url"].getStr == "mxc://localhost/a"

    check client_membership_members.memberEventsAccessPolicy(false, true).errcode == "M_NOT_FOUND"
    check client_membership_members.memberEventsAccessPolicy(true, false).errcode == "M_FORBIDDEN"
    check client_membership_members.joinedMembersAccessPolicy(true, false).message == "You aren't a member of the room."
