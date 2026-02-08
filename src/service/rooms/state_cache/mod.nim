## state_cache/mod — service module.
##
## Ported from Rust service/rooms/state_cache/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/rooms/state_cache/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc appserviceInRoom*(self: Service; roomId: string; appservice: RegistrationInfo): bool =
  ## Ported from `appservice_in_room`.
  false

proc getAppserviceInRoomCacheUsage*(self: Service): (int, int) =
  ## Ported from `get_appservice_in_room_cache_usage`.
  discard

proc clearAppserviceInRoomCache*(self: Service) =
  ## Ported from `clear_appservice_in_room_cache`.
  discard

proc serverSeesUser*(self: Service; server: string; userId: string): bool =
  ## Ported from `server_sees_user`.
  false

proc userSeesUser*(self: Service; userA: string; userB: string): bool =
  ## Ported from `user_sees_user`.
  false

proc roomJoinedCount*(self: Service; roomId: string): uint64 =
  ## Ported from `room_joined_count`.
  0

proc roomInvitedCount*(self: Service; roomId: string): uint64 =
  ## Ported from `room_invited_count`.
  0

proc roomKnockedCount*(self: Service; roomId: string): uint64 =
  ## Ported from `room_knocked_count`.
  0

proc getInviteCount*(self: Service; roomId: string; userId: string): uint64 =
  ## Ported from `get_invite_count`.
  0

proc getKnockCount*(self: Service; roomId: string; userId: string): uint64 =
  ## Ported from `get_knock_count`.
  0

proc getLeftCount*(self: Service; roomId: string; userId: string): uint64 =
  ## Ported from `get_left_count`.
  0

proc getJoinedCount*(self: Service; roomId: string; userId: string): uint64 =
  ## Ported from `get_joined_count`.
  0

proc inviteState*(self: Service; userId: string; roomId: string): seq[Raw<AnyStrippedStateEvent]> =
  ## Ported from `invite_state`.
  @[]

proc knockState*(self: Service; userId: string; roomId: string): seq[Raw<AnyStrippedStateEvent]> =
  ## Ported from `knock_state`.
  @[]

proc leftState*(self: Service; userId: string; roomId: string): seq[Raw<AnyStrippedStateEvent]> =
  ## Ported from `left_state`.
  @[]

proc userMembership*(self: Service; userId: string; roomId: string): Option[MembershipState] =
  ## Ported from `user_membership`.
  none(MembershipState)

proc onceJoined*(self: Service; userId: string; roomId: string): bool =
  ## Ported from `once_joined`.
  false

proc isInvited*(self: Service; userId: string; roomId: string): bool =
  ## Ported from `is_invited`.
  false
