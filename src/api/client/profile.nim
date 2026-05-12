const
  RustPath* = "api/client/profile.rs"
  RustCrate* = "api"
  CanonicalProfileFields* = ["avatar_url", "blurhash", "displayname", "m.tz"]
  LegacyTimezoneField* = "us.cloke.msc4175.tz"

import std/[json, tables]

type
  ProfilePolicyResult* = tuple[ok: bool, errcode: string, message: string]

  ProfileData* = object
    displayName*: string
    avatarUrl*: string
    blurhash*: string
    timezone*: string
    profileFields*: Table[string, JsonNode]

proc profileData*(
  displayName, avatarUrl, blurhash, timezone: string;
  profileFields: Table[string, JsonNode];
): ProfileData =
  result = ProfileData(
    displayName: displayName,
    avatarUrl: avatarUrl,
    blurhash: blurhash,
    timezone: timezone,
    profileFields: initTable[string, JsonNode](),
  )
  for key, value in profileFields:
    result.profileFields[key] = if value.isNil: newJNull() else: value.copy()

proc profileData*(displayName = ""; avatarUrl = ""; blurhash = ""; timezone = ""): ProfileData =
  ProfileData(
    displayName: displayName,
    avatarUrl: avatarUrl,
    blurhash: blurhash,
    timezone: timezone,
    profileFields: initTable[string, JsonNode](),
  )

proc isCanonicalProfileField*(field: string): bool =
  field in CanonicalProfileFields or field == LegacyTimezoneField

proc profileAccessPolicy*(
  senderUser, targetUser: string;
  isAppservice = false;
): ProfilePolicyResult =
  if senderUser != targetUser and not isAppservice:
    return (false, "M_FORBIDDEN", "You cannot update the profile of another user.")
  (true, "", "")

proc profilePayload*(data: ProfileData): JsonNode =
  result = newJObject()
  if data.displayName.len > 0:
    result["displayname"] = %data.displayName
  if data.avatarUrl.len > 0:
    result["avatar_url"] = %data.avatarUrl
  if data.blurhash.len > 0:
    result["blurhash"] = %data.blurhash
  if data.timezone.len > 0:
    result["m.tz"] = %data.timezone
  for key, value in data.profileFields:
    if not isCanonicalProfileField(key):
      result[key] = if value.isNil: newJNull() else: value.copy()

proc profileFieldPayload*(data: ProfileData; field: string): tuple[ok: bool, payload: JsonNode] =
  case field
  of "":
    result = (true, profilePayload(data))
  of "displayname":
    result = (true, %*{"displayname": data.displayName})
  of "avatar_url":
    result = (true, %*{"avatar_url": data.avatarUrl})
    if data.blurhash.len > 0:
      result.payload["blurhash"] = %data.blurhash
  of "blurhash":
    if data.blurhash.len == 0:
      result = (false, newJObject())
    else:
      result = (true, %*{"blurhash": data.blurhash})
  of "m.tz", LegacyTimezoneField:
    if data.timezone.len == 0:
      result = (false, newJObject())
    else:
      result = (true, newJObject())
      result.payload[field] = %data.timezone
  else:
    if field in data.profileFields:
      result = (true, newJObject())
      result.payload[field] = if data.profileFields[field].isNil: newJNull() else: data.profileFields[field].copy()
    else:
      result = (false, newJObject())

proc firstProfileFieldValue*(node: JsonNode; keys: openArray[string]): JsonNode =
  if node.isNil or node.kind != JObject:
    return newJNull()
  for key in keys:
    if node.hasKey(key):
      return node[key]
  newJNull()

proc setProfileField*(data: var ProfileData; field: string; body: JsonNode) =
  case field
  of "displayname":
    let value = firstProfileFieldValue(body, ["displayname"])
    if value.kind == JNull:
      data.displayName = ""
    elif value.kind == JString:
      data.displayName = value.getStr("")
  of "avatar_url":
    let value = firstProfileFieldValue(body, ["avatar_url"])
    if value.kind == JNull:
      data.avatarUrl = ""
    elif value.kind == JString:
      data.avatarUrl = value.getStr("")
    let blurhash = firstProfileFieldValue(body, ["blurhash"])
    if blurhash.kind == JString:
      data.blurhash = blurhash.getStr("")
  of "blurhash":
    let value = firstProfileFieldValue(body, ["blurhash"])
    if value.kind == JNull:
      data.blurhash = ""
    elif value.kind == JString:
      data.blurhash = value.getStr("")
  of "m.tz", LegacyTimezoneField:
    let value = firstProfileFieldValue(body, [field, "m.tz", LegacyTimezoneField])
    if value.kind == JNull:
      data.timezone = ""
    elif value.kind == JString:
      data.timezone = value.getStr("")
  else:
    if body.isNil:
      data.profileFields[field] = newJNull()
    elif body.kind == JObject and body.hasKey(field):
      data.profileFields[field] = body[field].copy()
    else:
      data.profileFields[field] = body.copy()

proc deleteProfileField*(data: var ProfileData; field: string) =
  case field
  of "displayname":
    data.displayName = ""
  of "avatar_url":
    data.avatarUrl = ""
    data.blurhash = ""
  of "blurhash":
    data.blurhash = ""
  of "m.tz", LegacyTimezoneField:
    data.timezone = ""
    data.profileFields.del("m.tz")
    data.profileFields.del(LegacyTimezoneField)
  else:
    data.profileFields.del(field)

proc profileWriteResponse*(): JsonNode =
  newJObject()
