const
  RustPath* = "core/matrix/state_res/events/third_party_invite.rs"
  RustCrate* = "core"

import std/[algorithm, json]

import core/matrix/state_res/json_helpers

type
  RoomThirdPartyInviteEvent* = object
    event*: JsonNode

proc roomThirdPartyInviteEvent*(event: JsonNode): RoomThirdPartyInviteEvent =
  RoomThirdPartyInviteEvent(event: if event.isNil: newJObject() else: event)

proc content(event: RoomThirdPartyInviteEvent): JsonNode =
  if event.event.isNil or event.event.kind != JObject:
    return newJObject()
  event.event.jsonContent()

proc publicKeys*(
  event: RoomThirdPartyInviteEvent
): tuple[ok: bool, keys: seq[string], message: string] =
  result = (true, @[], "")
  let content = event.content()
  var keys: seq[string] = @[]
  let publicKey = content.jsonField("public_key")
  if publicKey.kind == JString and publicKey.getStr("").len > 0:
    keys.add(publicKey.getStr())
  elif publicKey.kind notin {JNull, JString}:
    return (false, @[], "invalid `public_key` field in `m.room.third_party_invite` event")

  let publicKeys = content.jsonField("public_keys")
  if publicKeys.kind == JArray:
    for item in publicKeys:
      let itemPublicKey = item.jsonField("public_key")
      if item.kind != JObject or itemPublicKey.kind != JString or itemPublicKey.getStr("").len == 0:
        return (false, @[], "invalid `public_keys` entry in `m.room.third_party_invite` event")
      keys.add(itemPublicKey.getStr())
  elif publicKeys.kind != JNull:
    return (false, @[], "invalid `public_keys` field in `m.room.third_party_invite` event")

  keys.sort(system.cmp[string])
  for key in keys:
    if result.keys.len == 0 or result.keys[^1] != key:
      result.keys.add(key)
