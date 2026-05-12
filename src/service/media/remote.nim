import std/[options, strutils]

const
  RustPath* = "service/media/remote.rs"
  RustCrate* = "service"

type
  RemoteMediaPolicy* = object
    blockedHosts*: seq[string]
    forbiddenServers*: seq[string]
    freezeLegacyMedia*: bool
    requestLegacyMedia*: bool

  RemoteMediaContent* = object
    content*: seq[byte]
    contentType*: Option[string]
    contentDisposition*: Option[string]
    location*: Option[string]

proc initRemoteMediaPolicy*(): RemoteMediaPolicy =
  RemoteMediaPolicy(
    blockedHosts: @[],
    forbiddenServers: @[],
    freezeLegacyMedia: true,
    requestLegacyMedia: false,
  )

proc fetchAuthorized*(policy: RemoteMediaPolicy; serverName: string): bool =
  let host = serverName.toLowerAscii()
  for blocked in policy.blockedHosts:
    if blocked.len > 0 and host.contains(blocked.toLowerAscii()):
      return false
  for forbidden in policy.forbiddenServers:
    if forbidden.len > 0 and host == forbidden.toLowerAscii():
      return false
  true

proc legacyFetchAllowed*(policy: RemoteMediaPolicy): bool =
  not policy.freezeLegacyMedia

proc shouldTryLegacyFallback*(policy: RemoteMediaPolicy; errcode: string; statusCode: int): bool =
  if not policy.requestLegacyMedia:
    return false
  if errcode in ["M_NOT_FOUND", "M_UNRECOGNIZED"]:
    return true
  statusCode in 300 .. 599

proc contentFromLocation*(
  location: string;
  content: openArray[byte];
  contentType: Option[string] = none(string);
  contentDisposition: Option[string] = none(string);
): RemoteMediaContent =
  RemoteMediaContent(
    content: @content,
    contentType: contentType,
    contentDisposition: contentDisposition,
    location: some(location),
  )
