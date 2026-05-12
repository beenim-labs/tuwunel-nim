const
  RustPath* = "service/users/profile.rs"
  RustCrate* = "service"

import std/[algorithm, json, options, tables]

import service/users/device

proc setDisplayName*(service: var UserService; userId: string; displayName: Option[string]) =
  if userId notin service.users:
    return
  var user = service.users[userId]
  user.displayName = if displayName.isSome: displayName.get() else: ""
  service.users[userId] = user

proc displayName*(service: UserService; userId: string): StringFetchResult =
  if userId notin service.users or service.users[userId].displayName.len == 0:
    return (false, "", "M_NOT_FOUND", "Display name not found.")
  (true, service.users[userId].displayName, "", "")

proc setAvatarUrl*(service: var UserService; userId: string; avatarUrl: Option[string]) =
  if userId notin service.users:
    return
  var user = service.users[userId]
  user.avatarUrl = if avatarUrl.isSome: avatarUrl.get() else: ""
  service.users[userId] = user

proc avatarUrl*(service: UserService; userId: string): StringFetchResult =
  if userId notin service.users or service.users[userId].avatarUrl.len == 0:
    return (false, "", "M_NOT_FOUND", "Avatar URL not found.")
  (true, service.users[userId].avatarUrl, "", "")

proc setBlurhash*(service: var UserService; userId: string; blurhash: Option[string]) =
  if userId notin service.users:
    return
  var user = service.users[userId]
  user.blurhash = if blurhash.isSome: blurhash.get() else: ""
  service.users[userId] = user

proc blurhash*(service: UserService; userId: string): StringFetchResult =
  if userId notin service.users or service.users[userId].blurhash.len == 0:
    return (false, "", "M_NOT_FOUND", "Blurhash not found.")
  (true, service.users[userId].blurhash, "", "")

proc setTimezone*(service: var UserService; userId: string; timezone: Option[string]) =
  if userId notin service.users:
    return
  var user = service.users[userId]
  user.timezone = if timezone.isSome: timezone.get() else: ""
  if timezone.isSome:
    user.profileFields["m.tz"] = %*{"value": timezone.get()}
  else:
    user.profileFields.del("m.tz")
  service.users[userId] = user

proc timezone*(service: UserService; userId: string): StringFetchResult =
  if userId notin service.users:
    return (false, "", "M_NOT_FOUND", "Timezone not found.")
  let user = service.users[userId]
  if user.timezone.len > 0:
    return (true, user.timezone, "", "")
  if "us.cloke.msc4175.tz" in user.profileFields:
    return (true, user.profileFields["us.cloke.msc4175.tz"]{"value"}.getStr(""), "", "")
  (false, "", "M_NOT_FOUND", "Timezone not found.")

proc setProfileKey*(service: var UserService; userId, profileKey: string; value: JsonNode) =
  if userId notin service.users:
    return
  var user = service.users[userId]
  if value.isNil:
    user.profileFields.del(profileKey)
  else:
    user.profileFields[profileKey] = value.copy()
  service.users[userId] = user

proc profileKey*(service: UserService; userId, profileKey: string): tuple[ok: bool, value: JsonNode] =
  if userId notin service.users or profileKey notin service.users[userId].profileFields:
    return (false, newJObject())
  (true, service.users[userId].profileFields[profileKey].copy())

proc allProfileKeys*(service: UserService; userId: string): seq[tuple[key: string, value: JsonNode]] =
  result = @[]
  if userId notin service.users:
    return
  for key, value in service.users[userId].profileFields:
    result.add((key, value.copy()))
  result.sort(proc(a, b: tuple[key: string, value: JsonNode]): int = cmp(a.key, b.key))

proc updateDisplayName*(service: var UserService; userId: string; displayName: Option[string]; rooms: openArray[string] = []) =
  discard rooms
  service.setDisplayName(userId, displayName)

proc updateAvatarUrl*(
  service: var UserService;
  userId: string;
  avatarUrl: Option[string];
  blurhashValue: Option[string];
  rooms: openArray[string] = [];
) =
  discard rooms
  service.setAvatarUrl(userId, avatarUrl)
  service.setBlurhash(userId, blurhashValue)
