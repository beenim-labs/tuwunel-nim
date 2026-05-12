const
  RustPath* = "core/matrix/event/id.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/[json, strutils]

import core/utils/hash/sha256 as sha256_utils
import core/utils/json as json_utils

proc base64UrlNoPad(bytes: openArray[byte]): string =
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  result = ""
  var idx = 0
  while idx + 2 < bytes.len:
    let chunk = (uint32(bytes[idx]) shl 16) or (uint32(bytes[idx + 1]) shl 8) or uint32(bytes[idx + 2])
    result.add(alphabet[int((chunk shr 18) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 12) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 6) and 0x3f'u32)])
    result.add(alphabet[int(chunk and 0x3f'u32)])
    inc idx, 3

  let remaining = bytes.len - idx
  if remaining == 1:
    let chunk = uint32(bytes[idx]) shl 16
    result.add(alphabet[int((chunk shr 18) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 12) and 0x3f'u32)])
  elif remaining == 2:
    let chunk = (uint32(bytes[idx]) shl 16) or (uint32(bytes[idx + 1]) shl 8)
    result.add(alphabet[int((chunk shr 18) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 12) and 0x3f'u32)])
    result.add(alphabet[int((chunk shr 6) and 0x3f'u32)])

proc roomVersionRequiresEventId*(roomVersion: string): bool =
  roomVersion in ["1", "2"]

proc referenceHash*(event: JsonNode): tuple[ok: bool, value: string, message: string] =
  let canonical = json_utils.toCanonicalObject(event)
  if not canonical.ok:
    return (false, "", canonical.message)
  let digest = sha256_utils.hash($canonical.value)
  (true, base64UrlNoPad(digest), "")

proc genEventId*(event: JsonNode; roomVersion: string): tuple[ok: bool, eventId: string, message: string] =
  if event.isNil or event.kind != JObject:
    return (false, "", "event must be an object")

  if roomVersionRequiresEventId(roomVersion):
    let existing = event{"event_id"}.getStr("")
    if existing.len > 0:
      return (true, existing, "")

  let hashed = referenceHash(event)
  if not hashed.ok:
    return (false, "", hashed.message)

  var eventId = "$" & hashed.value
  if roomVersionRequiresEventId(roomVersion):
    let origin = event{"origin"}.getStr("")
    if origin.strip().len > 0:
      eventId.add(":" & origin)
  (true, eventId, "")

proc genEventIdCanonicalJson*(
    raw: string;
    roomVersion: string
): tuple[ok: bool, eventId: string, event: JsonNode, message: string] =
  try:
    let event = parseJson(raw)
    let generated = genEventId(event, roomVersion)
    if not generated.ok:
      return (false, "", event, generated.message)
    (true, generated.eventId, event, "")
  except JsonParsingError as err:
    (false, "", newJObject(), err.msg)
