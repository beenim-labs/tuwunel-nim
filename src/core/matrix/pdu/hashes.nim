const
  RustPath* = "core/matrix/pdu/hashes.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

import core/utils/hash/sha256 as sha256_utils
import core/utils/json as json_utils

const Sha256Base64Len* = 43

type EventHashes* = object
  sha256*: string

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

proc eventHashes*(event: JsonNode): tuple[ok: bool, hashes: EventHashes, message: string] =
  let canonical = json_utils.toCanonicalObject(event)
  if not canonical.ok:
    return (false, EventHashes(), canonical.message)
  let digest = sha256_utils.hash($canonical.value)
  (true, EventHashes(sha256: base64UrlNoPad(digest)), "")
