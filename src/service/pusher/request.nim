const
  RustPath* = "service/pusher/request.rs"
  RustCrate* = "service"

import std/[json, strutils, uri]

type
  PusherKind* = enum
    pkHttp
    pkEmail
    pkUnknown

  Pusher* = object
    appId*: string
    pushkey*: string
    kind*: PusherKind
    url*: string
    data*: JsonNode
    format*: string

  PusherPolicyResult* = tuple[ok: bool, errcode: string, message: string]
  RequestPolicyResult* = tuple[ok: bool, destination: string, message: string]

proc httpPusher*(
  appId, pushkey, url: string;
  data: JsonNode = nil;
  format = "";
): Pusher =
  Pusher(
    appId: appId,
    pushkey: pushkey,
    kind: pkHttp,
    url: url,
    data: if data.isNil: newJObject() else: data.copy(),
    format: format,
  )

proc deletePusherIds*(appId, pushkey: string): Pusher =
  Pusher(appId: appId, pushkey: pushkey, kind: pkUnknown)

proc validateHttpUrl*(url: string): PusherPolicyResult =
  try:
    let parsed = parseUri(url)
    if parsed.scheme.len == 0 or parsed.hostname.len == 0:
      return (false, "M_INVALID_PARAM", "HTTP pusher URL is not a valid URL.")
    let scheme = parsed.scheme.toLowerAscii()
    if not (scheme == "http" or scheme == "https"):
      return (false, "M_INVALID_PARAM", "HTTP pusher URL is not a valid HTTP/HTTPS URL.")
    (true, "", "")
  except CatchableError as e:
    (false, "M_INVALID_PARAM", "HTTP pusher URL is not a valid URL: " & e.msg)

proc validatePusher*(pusher: Pusher): PusherPolicyResult =
  if pusher.pushkey.len > 512:
    return (false, "M_INVALID_PARAM", "Push key length cannot be greater than 512 bytes.")
  if pusher.appId.len > 64:
    return (false, "M_INVALID_PARAM", "App ID length cannot be greater than 64 bytes.")
  if pusher.kind == pkHttp:
    return validateHttpUrl(pusher.url)
  (true, "", "")

proc pushGatewayDestination*(dest, notificationPushPath: string): string =
  if notificationPushPath.len == 0:
    return dest
  dest.replace(notificationPushPath, "")

proc sendRequestPolicy*(
  dest: string;
  notificationPushPath = "/_matrix/push/v1/notify";
): RequestPolicyResult =
  let stripped = pushGatewayDestination(dest, notificationPushPath)
  let urlPolicy = validateHttpUrl(stripped)
  if not urlPolicy.ok:
    return (false, stripped, urlPolicy.message)
  (true, stripped, "")
