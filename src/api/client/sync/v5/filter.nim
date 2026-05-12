const
  RustPath* = "api/client/sync/v5/filter.rs"
  RustCrate* = "api"

import std/options

type
  ListFilters* = object
    isInvite*: Option[bool]
    isDm*: Option[bool]
    isEncrypted*: Option[bool]
    spaces*: seq[string]
    tags*: seq[string]
    notTags*: seq[string]
    roomTypes*: seq[string]
    notRoomTypes*: seq[string]

  RoomFilterMeta* = object
    roomId*: string
    membership*: Option[string]
    invited*: bool
    directAccountData*: bool
    directMember*: bool
    encrypted*: bool
    parentSpaces*: seq[string]
    tags*: seq[string]
    roomType*: string
    exists*: bool
    disabled*: bool
    banned*: bool
    visible*: bool
    onceJoined*: bool

proc listFilters*(): ListFilters =
  ListFilters(
    isInvite: none(bool),
    isDm: none(bool),
    isEncrypted: none(bool),
    spaces: @[],
    tags: @[],
    notTags: @[],
    roomTypes: @[],
    notRoomTypes: @[],
  )

proc roomFilterMeta*(roomId: string): RoomFilterMeta =
  RoomFilterMeta(
    roomId: roomId,
    membership: none(string),
    exists: true,
    visible: true,
    onceJoined: true,
  )

proc matchesAny(values, needles: openArray[string]): bool =
  for value in values:
    if value in needles:
      return true
  false

proc filterRoom*(filter: ListFilters; room: RoomFilterMeta): bool =
  if filter.isInvite.isSome:
    let invite =
      if room.membership.isSome:
        room.membership.get() == "invite"
      else:
        room.invited
    if invite != filter.isInvite.get():
      return false

  if filter.isDm.isSome:
    if room.directAccountData != filter.isDm.get() and room.directMember != filter.isDm.get():
      return false

  if filter.isEncrypted.isSome and room.encrypted != filter.isEncrypted.get():
    return false

  if filter.spaces.len > 0 and not room.parentSpaces.matchesAny(filter.spaces):
    return false

  if filter.notTags.len > 0 and room.tags.matchesAny(filter.notTags):
    return false
  if filter.tags.len > 0 and not room.tags.matchesAny(filter.tags):
    return false

  if filter.notRoomTypes.len > 0 and room.roomType in filter.notRoomTypes:
    return false
  if filter.roomTypes.len > 0 and room.roomType notin filter.roomTypes:
    return false

  true

proc filterRoomMeta*(room: RoomFilterMeta): bool =
  room.exists and not room.disabled and not room.banned and
    (room.visible or room.invited or room.onceJoined)
